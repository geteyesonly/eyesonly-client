import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eyesonly/services/api_exception.dart';
import 'package:eyesonly/services/device/api_service.dart';
import 'package:eyesonly/services/incoming_group_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await PushNotificationsService.processIncomingRemoteMessage(message);
}

class PushNotificationsService {
  static bool _firebaseInitialized = false;
  static bool _messageHandlingInitialized = false;
  static bool _localNotificationsInitialized = false;
  static const int _apnsTokenRetryAttempts = 15;
  static const Duration _apnsTokenRetryDelay = Duration(milliseconds: 400);
  static const String _syncedTokenKeyPrefix =
      'push_notifications_synced_token_';
  static const String _genericGroupNotificationBody =
      'There are new images for you';
  static const AndroidNotificationChannel _notificationChannel =
      AndroidNotificationChannel(
        'eyesonly_group_messages',
        'EyesOnly Messages',
        description: 'Notifications for encrypted group messages and updates.',
        importance: Importance.high,
      );
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initializeMessageHandling() async {
    try {
      await _ensureFirebaseInitialized();
    } catch (_) {
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _initializeLocalNotifications();

    if (_messageHandlingInitialized) {
      return;
    }
    _messageHandlingInitialized = true;

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );

    FirebaseMessaging.onMessage.listen(processIncomingRemoteMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(processIncomingRemoteMessage);
  }

  Future<void> enableForOrganizations({
    required Iterable<String> baseUrls,
    String? fallbackBaseUrl,
  }) async {
    final List<String> normalizedBaseUrls = _normalizeBaseUrls(
      baseUrls,
      fallbackBaseUrl: fallbackBaseUrl,
    );
    if (normalizedBaseUrls.isEmpty) {
      throw ApiException(
        'Add an organization first to enable push notifications.',
      );
    }

    await initializeMessageHandling();
    await _ensureFirebaseInitialized();
    await _requestSystemNotificationPermissions();

    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    final NotificationSettings permission = await messaging.requestPermission();
    final AuthorizationStatus status = permission.authorizationStatus;
    if (_shouldRequireGrantedPermission &&
        (status == AuthorizationStatus.denied ||
            status == AuthorizationStatus.notDetermined)) {
      throw ApiException('Notification permission is required.');
    }

    final String? registrationId = await _getFcmTokenEnsuringApnsReady(
      messaging,
    );
    final String normalizedRegistrationId = registrationId?.trim() ?? '';
    if (normalizedRegistrationId.isEmpty) {
      throw ApiException(
        'Could not get an FCM token for this device. Please try again.',
      );
    }

    await _registerTokenAcrossServers(
      baseUrls: normalizedBaseUrls,
      registrationId: normalizedRegistrationId,
    );
  }

  Future<void> enableForManagerServer({required String baseUrl}) async {
    await enableForOrganizations(baseUrls: <String>[baseUrl]);
  }

  Future<void> disableForOrganizations({
    required Iterable<String> baseUrls,
    String? fallbackBaseUrl,
  }) async {
    final List<String> normalizedBaseUrls = _normalizeBaseUrls(
      baseUrls,
      fallbackBaseUrl: fallbackBaseUrl,
    );
    if (normalizedBaseUrls.isEmpty) {
      throw ApiException(
        'Add an organization first to disable push notifications.',
      );
    }

    Object? lastError;
    for (final String baseUrl in normalizedBaseUrls) {
      try {
        final DeviceApiService deviceApiService = DeviceApiService(
          baseUrl: baseUrl,
        );
        await deviceApiService.deregisterDeviceFcm();
      } catch (error) {
        lastError = error;
      }
    }

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // Ignore local token cleanup issues.
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    for (final String baseUrl in normalizedBaseUrls) {
      await prefs.remove(_syncedTokenKey(baseUrl));
    }

    if (lastError != null) {
      if (lastError is ApiException) {
        throw lastError;
      }
      throw ApiException(
        'Could not disable push notifications on one or more organizations.',
      );
    }
  }

  Future<void> disableForManagerServer({required String baseUrl}) async {
    await disableForOrganizations(baseUrls: <String>[baseUrl]);
  }

  Future<void> syncTokenOnAppStart({
    required bool pushNotificationsEnabled,
    required Iterable<String> baseUrls,
    String? fallbackBaseUrl,
  }) async {
    if (!pushNotificationsEnabled) {
      return;
    }

    await initializeMessageHandling();

    final List<String> normalizedBaseUrls = _normalizeBaseUrls(
      baseUrls,
      fallbackBaseUrl: fallbackBaseUrl,
    );
    if (normalizedBaseUrls.isEmpty) {
      return;
    }

    try {
      await _ensureFirebaseInitialized();
    } catch (_) {
      // Firebase might not be configured yet. Startup should not fail for this.
      return;
    }

    final String? token = await _getFcmTokenEnsuringApnsReady(
      FirebaseMessaging.instance,
    );
    final String registrationId = token?.trim() ?? '';
    if (registrationId.isEmpty) {
      return;
    }

    await _registerTokenAcrossServers(
      baseUrls: normalizedBaseUrls,
      registrationId: registrationId,
      swallowErrors: true,
    );
  }

  Future<void> _registerTokenAcrossServers({
    required List<String> baseUrls,
    required String registrationId,
    bool swallowErrors = false,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    Object? lastError;

    for (final String baseUrl in baseUrls) {
      final String tokenKey = _syncedTokenKey(baseUrl);
      final String previousSyncedToken =
          prefs.getString(tokenKey)?.trim() ?? '';
      if (previousSyncedToken == registrationId) {
        continue;
      }

      final DeviceApiService deviceApiService = DeviceApiService(
        baseUrl: baseUrl,
      );

      try {
        await deviceApiService.registerDeviceFcm(
          registrationId: registrationId,
          deviceType: _deviceType,
        );
        await prefs.setString(tokenKey, registrationId);
      } catch (error) {
        lastError = error;
        if (!swallowErrors) {
          if (error is ApiException) {
            rethrow;
          }
          throw ApiException(
            'Could not enable push notifications for ${Uri.parse(baseUrl).host.isNotEmpty ? Uri.parse(baseUrl).host : baseUrl}.',
          );
        }
      }
    }

    if (!swallowErrors && lastError != null) {
      if (lastError is ApiException) {
        throw lastError;
      }
      throw ApiException(
        'Could not enable push notifications on one or more organizations.',
      );
    }
  }

  List<String> _normalizeBaseUrls(
    Iterable<String> baseUrls, {
    String? fallbackBaseUrl,
  }) {
    final List<String> normalized = baseUrls
        .map((String baseUrl) => baseUrl.trim())
        .where((String baseUrl) => baseUrl.isNotEmpty)
        .toSet()
        .toList();
    final String normalizedFallbackBaseUrl = fallbackBaseUrl?.trim() ?? '';
    if (normalizedFallbackBaseUrl.isNotEmpty &&
        !normalized.contains(normalizedFallbackBaseUrl)) {
      normalized.add(normalizedFallbackBaseUrl);
    }
    return normalized;
  }

  String get _deviceType {
    if (kIsWeb) {
      return 'web';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    return 'android';
  }

  bool get _shouldRequireGrantedPermission {
    if (kIsWeb) {
      return true;
    }
    return Platform.isIOS || Platform.isMacOS;
  }

  Future<void> _ensureFirebaseInitialized() async {
    if (_firebaseInitialized || Firebase.apps.isNotEmpty) {
      _firebaseInitialized = true;
      return;
    }

    try {
      await Firebase.initializeApp();
      _firebaseInitialized = true;
    } catch (_) {
      throw ApiException(
        'Firebase is not configured yet on this app. Add Firebase configuration files first.',
      );
    }
  }

  Future<String?> _getFcmTokenEnsuringApnsReady(
    FirebaseMessaging messaging,
  ) async {
    if (Platform.isIOS && !_hasApnsToken(await messaging.getAPNSToken())) {
      await _waitForApnsToken(messaging);
    }

    try {
      return await messaging.getToken();
    } catch (_) {
      throw ApiException(
        'Push token is not ready yet. Please wait a moment and try again.',
      );
    }
  }

  Future<void> _waitForApnsToken(FirebaseMessaging messaging) async {
    for (int i = 0; i < _apnsTokenRetryAttempts; i++) {
      final String? apnsToken = await messaging.getAPNSToken();
      if (_hasApnsToken(apnsToken)) {
        return;
      }
      await Future<void>.delayed(_apnsTokenRetryDelay);
    }

    throw ApiException(
      'APNs token has not been set yet. Please allow notifications and try again.',
    );
  }

  bool _hasApnsToken(String? token) {
    return (token?.trim().isNotEmpty ?? false);
  }

  static Future<void> processIncomingRemoteMessage(
    RemoteMessage message,
  ) async {
    try {
      if (!_firebaseInitialized && Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
        _firebaseInitialized = true;
      } else {
        _firebaseInitialized = true;
      }
    } catch (_) {
      // Ignore Firebase initialization failures while handling best-effort notifications.
    }

    await _initializeLocalNotifications();

    final IncomingGroupNotificationService notificationService =
        IncomingGroupNotificationService();
    final DecryptedGroupNotification? decryptedNotification =
        await notificationService.decryptMessageData(message.data);
    final String messageGroupId =
        (message.data['group'] as String?)?.trim() ?? '';
    final bool hasEncryptedGroupPayload =
        messageGroupId.isNotEmpty &&
        ((message.data['encrypted_payload'] as String?)?.trim().isNotEmpty ??
            false) &&
        ((message.data['nonce'] as String?)?.trim().isNotEmpty ?? false);

    String? body;
    String title = 'EyesOnly';
    String payload = '';

    if (decryptedNotification != null) {
      body = decryptedNotification.body;
      title = decryptedNotification.title;
      payload = decryptedNotification.groupId;
    } else {
      final String? notificationBody = message.notification?.body?.trim();
      if (notificationBody != null && notificationBody.isNotEmpty) {
        body = notificationBody;
      } else {
        body = notificationService.fallbackBody(message.data);
      }

      final String? notificationTitle = message.notification?.title?.trim();
      if (notificationTitle != null && notificationTitle.isNotEmpty) {
        title = notificationTitle;
      }

      if ((body == null || body.isEmpty) && hasEncryptedGroupPayload) {
        // Background isolates may not always be able to decrypt; still show a
        // non-sensitive OS notification so encrypted pushes are not dropped.
        body = _genericGroupNotificationBody;
        payload = messageGroupId;
      }
    }

    if (body == null || body.isEmpty) {
      return;
    }

    await _localNotificationsPlugin.show(
      id: body.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _notificationChannel.id,
          _notificationChannel.name,
          channelDescription: _notificationChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  static Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) {
      return;
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings();

    await _localNotificationsPlugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidPlugin?.createNotificationChannel(_notificationChannel);

    _localNotificationsInitialized = true;
  }

  Future<void> _requestSystemNotificationPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidPlugin?.requestNotificationsPermission();

    final IOSFlutterLocalNotificationsPlugin? iosPlugin =
        _localNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }

  String _syncedTokenKey(String baseUrl) {
    return '$_syncedTokenKeyPrefix${Uri.encodeComponent(baseUrl.trim())}';
  }
}
