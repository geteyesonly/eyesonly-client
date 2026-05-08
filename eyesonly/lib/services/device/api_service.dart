import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api_exception.dart';
import '../api_service_support.dart';
import '../installation_id_store.dart';
import 'api_endpoints.dart';
import 'auth_token_store.dart';
import 'allowed_algorithms.dart';
import 'hkdf_info.dart';

class DeviceSelfStatus {
  const DeviceSelfStatus({
    required this.deviceIdentifier,
    required this.isRegistered,
    this.registeredAt,
    this.groupNames = const <String>[],
    this.organizationName,
  });

  final String deviceIdentifier;
  final bool isRegistered;
  final DateTime? registeredAt;
  final List<String> groupNames;
  final String? organizationName;

  factory DeviceSelfStatus.fromJson(Map<String, dynamic> json) {
    final dynamic registeredAtRaw = json['registered_at'];
    return DeviceSelfStatus(
      deviceIdentifier: (json['device_identifier'] as String?) ?? '',
      isRegistered: (json['is_registered'] as bool?) ?? false,
      registeredAt: registeredAtRaw is String && registeredAtRaw.isNotEmpty
          ? DateTime.tryParse(registeredAtRaw)
          : null,
      groupNames: (json['group_names'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
      organizationName: json['organization_name'] as String?,
    );
  }
}

class DeviceGroup {
  const DeviceGroup({
    required this.uuid,
    required this.encryptedName,
    required this.nameNonce,
    this.userRole,
  });

  final String uuid;
  final String encryptedName;
  final String nameNonce;
  final String? userRole;

  factory DeviceGroup.fromJson(Map<String, dynamic> json) {
    return DeviceGroup(
      uuid: (json['uuid'] as String?)?.trim() ?? '',
      encryptedName: (json['encrypted_name'] as String?)?.trim() ?? '',
      nameNonce: (json['name_nonce'] as String?)?.trim() ?? '',
      userRole: (json['user_role'] as String?)?.trim(),
    );
  }
}

class DeviceGroupKeyEnvelope {
  const DeviceGroupKeyEnvelope({
    required this.groupId,
    required this.encryptedGroupKey,
    this.scope,
    this.keyWrapAlgorithm,
    this.recipientKeyFingerprint,
    this.createdAt,
  });

  final String groupId;
  final String encryptedGroupKey;
  final String? scope;
  final String? keyWrapAlgorithm;
  final String? recipientKeyFingerprint;
  final DateTime? createdAt;

  factory DeviceGroupKeyEnvelope.fromJson(Map<String, dynamic> json) {
    final String? createdAtRaw = (json['created_at'] as String?)?.trim();
    return DeviceGroupKeyEnvelope(
      groupId: (json['group'] as String?)?.trim() ?? '',
      encryptedGroupKey: (json['encrypted_group_key'] as String?)?.trim() ?? '',
      scope: (json['scope'] as String?)?.trim(),
      keyWrapAlgorithm: (json['key_wrap_algorithm'] as String?)?.trim(),
      recipientKeyFingerprint:
          (json['recipient_key_fingerprint'] as String?)?.trim(),
      createdAt: createdAtRaw != null && createdAtRaw.isNotEmpty
          ? DateTime.tryParse(createdAtRaw)
          : null,
    );
  }
}

class DeviceEncryptedImage {
  const DeviceEncryptedImage({
    required this.imageUuid,
    required this.payloadNonce,
    required this.encryptedContentKey,
    this.encryptedBlobName,
    this.createdAt,
    this.encryptedCaption,
    this.cryptoVersion,
    this.encryptionAlgorithm,
    this.ciphertextHashSha256,
    this.keyWrapAlgorithm,
    this.recipientKeyFingerprint,
    this.expiresAt,
  });

  final String imageUuid;
  final String? encryptedBlobName;
  final String payloadNonce;
  final String encryptedContentKey;
  final DateTime? createdAt;
  final String? encryptedCaption;
  final int? cryptoVersion;
  final String? encryptionAlgorithm;
  final String? ciphertextHashSha256;
  final String? keyWrapAlgorithm;
  final String? recipientKeyFingerprint;
  final DateTime? expiresAt;

  factory DeviceEncryptedImage.fromJson(Map<String, dynamic> json) {
    final String? createdAtRaw = (json['created_at'] as String?)?.trim();
    final String? expiresAtRaw = (json['expires_at'] as String?)?.trim();
    return DeviceEncryptedImage(
      imageUuid: (json['image_uuid'] as String?)?.trim() ?? '',
      encryptedBlobName: (json['encrypted_blob_name'] as String?)?.trim(),
      encryptedCaption: (json['encrypted_caption'] as String?)?.trim(),
      cryptoVersion: (json['crypto_version'] as num?)?.toInt(),
      encryptionAlgorithm: (json['encryption_algorithm'] as String?)?.trim(),
      payloadNonce: (json['payload_nonce'] as String?)?.trim() ?? '',
      ciphertextHashSha256:
          (json['ciphertext_hash_sha256'] as String?)?.trim(),
      keyWrapAlgorithm: (json['key_wrap_algorithm'] as String?)?.trim(),
      recipientKeyFingerprint:
          (json['recipient_key_fingerprint'] as String?)?.trim(),
      encryptedContentKey:
          (json['encrypted_content_key'] as String?)?.trim() ?? '',
      createdAt: createdAtRaw != null && createdAtRaw.isNotEmpty
          ? DateTime.tryParse(createdAtRaw)
          : null,
      expiresAt: expiresAtRaw != null && expiresAtRaw.isNotEmpty
          ? DateTime.tryParse(expiresAtRaw)
          : null,
    );
  }
}

class DeviceEncryptedImageDayGroup {
  const DeviceEncryptedImageDayGroup({
    required this.day,
    required this.images,
  });

  final DateTime? day;
  final List<DeviceEncryptedImage> images;

  factory DeviceEncryptedImageDayGroup.fromJson(Map<String, dynamic> json) {
    final String? dayRaw = (json['day'] as String?)?.trim();
    return DeviceEncryptedImageDayGroup(
      day: dayRaw != null && dayRaw.isNotEmpty ? DateTime.tryParse(dayRaw) : null,
      images: (json['images'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(DeviceEncryptedImage.fromJson)
          .where(
            (DeviceEncryptedImage image) =>
                image.imageUuid.isNotEmpty &&
                image.payloadNonce.isNotEmpty &&
                image.encryptedContentKey.isNotEmpty,
          )
          .toList(),
    );
  }
}

class DeviceEncryptedImageGroup {
  const DeviceEncryptedImageGroup({
    required this.groupId,
    required this.encryptedName,
    required this.days,
  });

  final String groupId;
  final String encryptedName;
  final List<DeviceEncryptedImageDayGroup> days;

  factory DeviceEncryptedImageGroup.fromJson(Map<String, dynamic> json) {
    return DeviceEncryptedImageGroup(
      groupId: (json['group'] as String?)?.trim() ?? '',
      encryptedName: (json['encrypted_name'] as String?)?.trim() ?? '',
      days: (json['days'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(DeviceEncryptedImageDayGroup.fromJson)
          .toList(),
    );
  }
}

class DeviceEncryptedImageListResponse {
  const DeviceEncryptedImageListResponse({
    required this.groups,
    this.nextCursor,
  });

  final List<DeviceEncryptedImageGroup> groups;
  final String? nextCursor;

  factory DeviceEncryptedImageListResponse.fromJson(Map<String, dynamic> json) {
    final String? nextCursor = (json['next_cursor'] as String?)?.trim();
    return DeviceEncryptedImageListResponse(
      groups: (json['groups'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(DeviceEncryptedImageGroup.fromJson)
          .where((DeviceEncryptedImageGroup group) => group.groupId.isNotEmpty)
          .toList(),
      nextCursor: nextCursor != null && nextCursor.isNotEmpty ? nextCursor : null,
    );
  }
}

class DeviceApiService {
  DeviceApiService({
    required this.baseUrl,
    String? accessToken,
    http.Client? client,
    DeviceAuthTokenStore? tokenStore,
    InstallationIdStore? installationIdStore,
    FlutterSecureStorage? secureStorage,
    bool autoAuthenticate = true,
  }) : _accessToken = accessToken,
       _client = client ?? http.Client(),
       _tokenStore = tokenStore ?? DeviceAuthTokenStore(),
       _installationIdStore = installationIdStore ?? InstallationIdStore(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _autoAuthenticate = autoAuthenticate;

  final String baseUrl;
  final http.Client _client;
  final DeviceAuthTokenStore _tokenStore;
  final InstallationIdStore _installationIdStore;
  final bool _autoAuthenticate;
  String? _accessToken;
  String _tokenType = 'Bearer';
  DateTime? _expiresAt;
  Future<void>? _authInFlight;

  // For private key access
  static const String _privateKeyKey = 'device_private_key';
  static const String _publicKeyKey = 'device_public_key';
  static const String _genericAuthenticationFailureMessage =
      'This device could not be authenticated with this server.';
    static const String _noGroupsYetMessage =
      'You are not in any groups yet.';
  final FlutterSecureStorage _secureStorage;


  void setAccessToken(String? token) {
    _accessToken = token;
    _tokenType = 'Bearer';
    _expiresAt = null;
  }

  Uri _uri(String path) {
    return ApiServiceSupport.buildUri(baseUrl: baseUrl, path: path);
  }

  Map<String, String> _headers({bool includeAuth = true, String? deviceIdentifier}) {
    return ApiServiceSupport.jsonHeaders(
      authorization:
          includeAuth && _accessToken != null ? '$_tokenType $_accessToken' : null,
      extraHeaders: deviceIdentifier != null && deviceIdentifier.isNotEmpty
          ? <String, String>{'X-Device-Identifier': deviceIdentifier}
          : null,
    );
  }

  Future<List<dynamic>> getList(String endpoint) async {
    await _ensureDeviceAuthenticated();

    final String deviceIdentifier = await _installationIdStore.getOrCreateInstallationId();
    http.Response response = await _client.get(
      _uri(endpoint),
      headers: _headers(deviceIdentifier: deviceIdentifier),
    );

    final bool canRetryWithDeviceAuth =
        _autoAuthenticate &&
        response.statusCode == 401 &&
        (_accessToken == null || _expiresAt != null);

    if (canRetryWithDeviceAuth) {
      await _tokenStore.clearCredentials();
      _accessToken = null;
      _expiresAt = null;
      _tokenType = 'Bearer';

      await _authenticateDevice();
      response = await _client.get(
        _uri(endpoint),
        headers: _headers(deviceIdentifier: deviceIdentifier),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'GET request failed',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    return ApiServiceSupport.decodeList(response.body);
  }

  Future<List<DeviceGroup>> getGroups({
    String endpoint = DeviceApiEndpoints.deviceGroups,
  }) async {
    final List<dynamic> decoded = await getList(endpoint);
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(DeviceGroup.fromJson)
        .where((DeviceGroup group) => group.uuid.isNotEmpty)
        .toList();
  }

  Future<DeviceEncryptedImageListResponse> getEncryptedImages({
    String? cursor,
    int? limit,
    String endpoint = DeviceApiEndpoints.deviceListEncryptedImages,
  }) async {
    await _ensureDeviceAuthenticated();
    final String deviceIdentifier =
        await _installationIdStore.getOrCreateInstallationId();

    Uri uri = _uri(endpoint);
    final Map<String, String> queryParameters = <String, String>{
      if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
      if (limit != null) 'limit': limit.toString(),
    };
    if (queryParameters.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParameters);
    }

    http.Response response = await _client.get(
      uri,
      headers: _headers(deviceIdentifier: deviceIdentifier),
    );

    final bool canRetryWithDeviceAuth =
        _autoAuthenticate &&
        response.statusCode == 401 &&
        (_accessToken == null || _expiresAt != null);

    if (canRetryWithDeviceAuth) {
      await _tokenStore.clearCredentials();
      _accessToken = null;
      _expiresAt = null;
      _tokenType = 'Bearer';

      await _authenticateDevice();
      response = await _client.get(
        uri,
        headers: _headers(deviceIdentifier: deviceIdentifier),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to fetch encrypted images',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    return DeviceEncryptedImageListResponse.fromJson(
      ApiServiceSupport.decodeObject(response.body),
    );
  }

  Future<List<int>> downloadEncryptedImageBlob({
    required String imageUuid,
  }) async {
    await _ensureDeviceAuthenticated();
    final String deviceIdentifier =
        await _installationIdStore.getOrCreateInstallationId();

    final Uri uri = _uri(
      DeviceApiEndpoints.deviceEncryptedImageBlob(imageUuid),
    );
    final http.Response response = await _getWithDeviceAuth(
      uri: uri,
      deviceIdentifier: deviceIdentifier,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to download encrypted image payload',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    if (response.bodyBytes.isEmpty) {
      throw ApiException('Encrypted image payload was empty.');
    }

    return response.bodyBytes;
  }

  Future<http.Response> _getWithDeviceAuth({
    required Uri uri,
    required String deviceIdentifier,
  }) async {
    http.Response response = await _client.get(
      uri,
      headers: _headers(deviceIdentifier: deviceIdentifier),
    );

    final bool canRetryWithDeviceAuth =
        _autoAuthenticate &&
        response.statusCode == 401 &&
        (_accessToken == null || _expiresAt != null);

    if (canRetryWithDeviceAuth) {
      await _tokenStore.clearCredentials();
      _accessToken = null;
      _expiresAt = null;
      _tokenType = 'Bearer';

      await _authenticateDevice();
      response = await _client.get(
        uri,
        headers: _headers(deviceIdentifier: deviceIdentifier),
      );
    }

    return response;
  }

  Future<void> leaveGroup({
    required String groupId,
    String endpoint = DeviceApiEndpoints.deviceLeaveGroup,
  }) async {
    await _ensureDeviceAuthenticated();
    final String deviceIdentifier =
        await _installationIdStore.getOrCreateInstallationId();

    http.Response response = await _client.post(
      _uri(endpoint),
      headers: _headers(deviceIdentifier: deviceIdentifier),
      body: jsonEncode(<String, String>{'group': groupId}),
    );

    final bool canRetryWithDeviceAuth =
        _autoAuthenticate &&
        response.statusCode == 401 &&
        (_accessToken == null || _expiresAt != null);

    if (canRetryWithDeviceAuth) {
      await _tokenStore.clearCredentials();
      _accessToken = null;
      _expiresAt = null;
      _tokenType = 'Bearer';

      await _authenticateDevice();
      response = await _client.post(
        _uri(endpoint),
        headers: _headers(deviceIdentifier: deviceIdentifier),
        body: jsonEncode(<String, String>{'group': groupId}),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Leave group request failed',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
  }

  Future<void> registerDeviceFcm({
    required String registrationId,
    required String deviceType,
    String endpoint = DeviceApiEndpoints.deviceFcm,
  }) async {
    await _ensureDeviceAuthenticated();
    final String deviceIdentifier =
        await _installationIdStore.getOrCreateInstallationId();

    http.Response response = await _client.post(
      _uri(endpoint),
      headers: _headers(deviceIdentifier: deviceIdentifier),
      body: jsonEncode(<String, String>{
        'registration_id': registrationId,
        'type': deviceType,
      }),
    );

    final bool canRetryWithDeviceAuth =
        _autoAuthenticate &&
        response.statusCode == 401 &&
        (_accessToken == null || _expiresAt != null);

    if (canRetryWithDeviceAuth) {
      await _tokenStore.clearCredentials();
      _accessToken = null;
      _expiresAt = null;
      _tokenType = 'Bearer';

      await _authenticateDevice();
      response = await _client.post(
        _uri(endpoint),
        headers: _headers(deviceIdentifier: deviceIdentifier),
        body: jsonEncode(<String, String>{
          'registration_id': registrationId,
          'type': deviceType,
        }),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Registering push notifications failed.',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
  }

  Future<void> deregisterDeviceFcm({
    String endpoint = DeviceApiEndpoints.deviceFcmDeregister,
  }) async {
    await _ensureDeviceAuthenticated();
    final String deviceIdentifier =
        await _installationIdStore.getOrCreateInstallationId();

    final http.Request request = http.Request('DELETE', _uri(endpoint));
    request.headers.addAll(_headers(deviceIdentifier: deviceIdentifier));

    http.Response response = await http.Response.fromStream(
      await _client.send(request),
    );

    final bool canRetryWithDeviceAuth =
        _autoAuthenticate &&
        response.statusCode == 401 &&
        (_accessToken == null || _expiresAt != null);

    if (canRetryWithDeviceAuth) {
      await _tokenStore.clearCredentials();
      _accessToken = null;
      _expiresAt = null;
      _tokenType = 'Bearer';

      await _authenticateDevice();
      final http.Request retryRequest = http.Request('DELETE', _uri(endpoint));
      retryRequest.headers.addAll(
        _headers(deviceIdentifier: deviceIdentifier),
      );
      response = await http.Response.fromStream(
        await _client.send(retryRequest),
      );
    }

    if (response.statusCode == 404) {
      return;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Disabling push notifications failed.',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
  }

  Future<void> deleteEncryptedImage({
    required String groupId,
    required String imageUuid,
    String endpoint = DeviceApiEndpoints.deleteEncryptedImage,
  }) async {
    await _ensureDeviceAuthenticated();
    final String deviceIdentifier =
        await _installationIdStore.getOrCreateInstallationId();

    Future<http.Response> sendDelete() async {
      final http.Request request = http.Request('DELETE', _uri(endpoint));
      request.headers.addAll(_headers(deviceIdentifier: deviceIdentifier));
      request.body = jsonEncode(<String, String>{
        'group': groupId,
        'image_uuid': imageUuid,
      });
      final http.StreamedResponse streamedResponse = await _client.send(request);
      return http.Response.fromStream(streamedResponse);
    }

    http.Response response = await sendDelete();

    final bool canRetryWithDeviceAuth =
        _autoAuthenticate &&
        response.statusCode == 401 &&
        (_accessToken == null || _expiresAt != null);

    if (canRetryWithDeviceAuth) {
      await _tokenStore.clearCredentials();
      _accessToken = null;
      _expiresAt = null;
      _tokenType = 'Bearer';

      await _authenticateDevice();
      response = await sendDelete();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Delete image request failed',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
  }

  Future<List<DeviceGroupKeyEnvelope>> getGroupKeyEnvelopes({
    required List<String> groupIds,
    List<String>? scopes,
    String endpoint = DeviceApiEndpoints.deviceGroupKeyEnvelope,
  }) async {
    final List<String> normalizedGroupIds = groupIds
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedGroupIds.isEmpty) {
      return <DeviceGroupKeyEnvelope>[];
    }

    await _ensureDeviceAuthenticated();
    final String deviceIdentifier =
        await _installationIdStore.getOrCreateInstallationId();

    http.Response response = await _client.post(
      _uri(endpoint),
      headers: _headers(deviceIdentifier: deviceIdentifier),
      body: jsonEncode(<String, dynamic>{
        'groups': normalizedGroupIds,
        if (scopes != null && scopes.isNotEmpty) 'scopes': scopes,
      }),
    );

    final bool canRetryWithDeviceAuth =
        _autoAuthenticate &&
        response.statusCode == 401 &&
        (_accessToken == null || _expiresAt != null);

    if (canRetryWithDeviceAuth) {
      await _tokenStore.clearCredentials();
      _accessToken = null;
      _expiresAt = null;
      _tokenType = 'Bearer';

      await _authenticateDevice();
      response = await _client.post(
        _uri(endpoint),
        headers: _headers(deviceIdentifier: deviceIdentifier),
        body: jsonEncode(<String, dynamic>{
          'groups': normalizedGroupIds,
          if (scopes != null && scopes.isNotEmpty) 'scopes': scopes,
        }),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to fetch group key envelopes',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(DeviceGroupKeyEnvelope.fromJson)
          .where(
            (DeviceGroupKeyEnvelope envelope) =>
                envelope.groupId.isNotEmpty &&
                envelope.encryptedGroupKey.isNotEmpty,
          )
          .toList();
    }

    throw ApiException(
      'Expected a JSON list response for group key envelopes',
      responseBody: response.body,
    );
  }

  Future<void> _ensureDeviceAuthenticated() async {
    if (!_autoAuthenticate) {
      return;
    }
    if (_hasUsableInMemoryToken()) {
      return;
    }

    final Future<void>? activeAuth = _authInFlight;
    if (activeAuth != null) {
      await activeAuth;
      return;
    }

    final Future<void> newAuth = _authenticateDevice();
    _authInFlight = newAuth;
    try {
      await newAuth;
    } finally {
      _authInFlight = null;
    }
  }

  bool _hasUsableInMemoryToken() {
    final String? token = _accessToken;
    if (token == null || token.isEmpty) {
      return false;
    }
    return !_isExpired(_expiresAt);
  }

  bool _isExpired(DateTime? expiresAt) {
    if (expiresAt == null) {
      return false;
    }
    return DateTime.now().isAfter(
      expiresAt.subtract(const Duration(seconds: 30)),
    );
  }

    /// Public method to authenticate the device (calls the private method internally)
  Future<void> authenticateDevice() => _authenticateDevice();

  Future<void> _authenticateDevice() async {
    final DeviceAuthCredentials? existingCredentials =
        await _tokenStore.readCredentials();
    if (existingCredentials != null && !_isExpired(existingCredentials.expiresAt)) {
      _accessToken = existingCredentials.accessToken;
      _tokenType = existingCredentials.tokenType.trim().isEmpty
          ? 'Bearer'
          : existingCredentials.tokenType;
      _expiresAt = existingCredentials.expiresAt;
      return;
    }


    final String deviceIdentifier =
        await _installationIdStore.getOrCreateInstallationId();

    final Map<String, dynamic> challengeData = await _postObject(
      endpoint: DeviceApiEndpoints.deviceAuthChallenge,
      body: <String, String>{'device_identifier': deviceIdentifier},
      includeAuth: false,
      failureMessage: 'Device auth challenge request failed',
    );

    // Decrypt the encrypted_challenge using device private key
    final String decryptedChallenge;
    try {
      decryptedChallenge = await _decryptChallenge(challengeData);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(_genericAuthenticationFailureMessage);
    }

    final Map<String, dynamic> tokenData = await _postObject(
      endpoint: DeviceApiEndpoints.deviceAuthToken,
      body: <String, String>{
        'device_identifier': deviceIdentifier,
        'challenge': decryptedChallenge,
      },
      includeAuth: false,
      failureMessage: 'Device auth token request failed',
    );

    final String token = (tokenData['access_token'] as String?)?.trim() ?? '';
    if (token.isEmpty) {
      throw ApiException('Device auth succeeded but access token is missing.');
    }

    final String tokenType =
        (tokenData['token_type'] as String?)?.trim().isNotEmpty == true
        ? (tokenData['token_type'] as String).trim()
        : 'Bearer';
    final DateTime? expiresAt = DateTime.tryParse(
      (tokenData['expires_at'] as String?) ?? '',
    );

    await _tokenStore.saveCredentials(
      DeviceAuthCredentials(
        accessToken: token,
        tokenType: tokenType,
        expiresAt: expiresAt,
      ),
    );

    _accessToken = token;
    _tokenType = tokenType;
    _expiresAt = expiresAt;
  }

  Future<Map<String, dynamic>> _postObject({
    required String endpoint,
    required Map<String, String> body,
    required bool includeAuth,
    required String failureMessage,
  }) async {
    final http.Response response = await _client.post(
      _uri(endpoint),
      headers: _headers(includeAuth: includeAuth),
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        failureMessage,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    return ApiServiceSupport.decodeObject(response.body);
  }


  Future<String> _decryptChallenge(Map<String, dynamic> challengeData) async {

    final dynamic encryptedChallenge = challengeData['encrypted_challenge'];
    if (encryptedChallenge is! Map<String, dynamic>) {
      throw ApiException('Device auth challenge response missing encrypted_challenge');
    }
    final String? ciphertextB64 = encryptedChallenge['ciphertext'] as String?;
    final String? nonceB64 = encryptedChallenge['nonce'] as String?;
    final String? ephemeralPublicKeyB64 = encryptedChallenge['ephemeral_public_key'] as String?;
    final String? algorithm = encryptedChallenge['algorithm'] as String?;

    if (ciphertextB64 == null || nonceB64 == null || ephemeralPublicKeyB64 == null || algorithm == null) {
      throw ApiException('Device auth challenge response missing required fields');
    }
    if (!allowedDeviceChallengeAlgorithms.contains(algorithm.toLowerCase())) {
      throw ApiException('Unsupported challenge algorithm: $algorithm');
    }
    // Get device private and public key from secure storage (X25519)
    final String? privateKeyB64 = await _secureStorage.read(key: _privateKeyKey);
    final String? publicKeyB64 = await _secureStorage.read(key: _publicKeyKey);

    if (privateKeyB64 == null || privateKeyB64.isEmpty) {
      throw ApiException(_noGroupsYetMessage);
    }
    if (publicKeyB64 == null || publicKeyB64.isEmpty) {
      throw ApiException(_noGroupsYetMessage);
    }
    final List<int> privateKeyBytes = base64Decode(privateKeyB64);
    final List<int> publicKeyBytes = base64Decode(publicKeyB64);

    // Ephemeral public key from server
    final List<int> ephemeralPublicKeyBytes = base64Decode(ephemeralPublicKeyB64);

    final SimplePublicKey devicePublicKey = SimplePublicKey(publicKeyBytes, type: KeyPairType.x25519);
    final SimplePublicKey ephemeralPublicKey = SimplePublicKey(ephemeralPublicKeyBytes, type: KeyPairType.x25519);
    // Construct the device keypair with the correct public key
    final SimpleKeyPair deviceKeyPair = SimpleKeyPairData(privateKeyBytes, publicKey: devicePublicKey, type: KeyPairType.x25519);

    // 1. ECDH: derive shared secret
    final sharedSecret = await X25519().sharedSecretKey(
      keyPair: deviceKeyPair,
      remotePublicKey: ephemeralPublicKey,
    );


    // 2. HKDF-SHA256 to derive 32-byte symmetric key
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );
    final hkdfKey = await hkdf.deriveKey(
      secretKey: sharedSecret,
      info: utf8.encode(deviceAuthHkdfInfo),
    );

    // 3. XChaCha20-Poly1305 decryption
    final nonce = base64Decode(nonceB64);
    final ciphertext = base64Decode(ciphertextB64);

    final macLength = 16;

    final actualCiphertext = ciphertext.sublist(0, ciphertext.length - macLength);
    final macBytes = ciphertext.sublist(ciphertext.length - macLength);

    final secretBox = SecretBox(
      actualCiphertext,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    //final secretBox = SecretBox(
    //  ciphertext,
    //  nonce: nonce,
    //  mac: Mac.empty, // Poly1305 MAC is verified by cryptography package
    //);
    final List<int> cleartext;
    try {
      cleartext = await Xchacha20.poly1305Aead().decrypt(
        secretBox,
        secretKey: hkdfKey,
      );
    } catch (_) {
      throw ApiException(_genericAuthenticationFailureMessage);
    }

    // 4. Return UTF-8 string
    try {
      return utf8.decode(cleartext);
    } catch (_) {
      throw ApiException(_genericAuthenticationFailureMessage);
    }
    // END DEBUG LOGGING
  }

  Future<DeviceSelfStatus> getSelfStatus({
    String endpoint = DeviceApiEndpoints.deviceStatus,
  }) async {
    // Always trigger device token preflight and send device headers
    await _ensureDeviceAuthenticated();
    final String deviceIdentifier = await _installationIdStore.getOrCreateInstallationId();
    final response = await _client.get(
      _uri(endpoint),
      headers: _headers(deviceIdentifier: deviceIdentifier),
    );
    final bool canRetryWithDeviceAuth =
        _autoAuthenticate &&
        response.statusCode == 401 &&
        (_accessToken == null || _expiresAt != null);
    if (canRetryWithDeviceAuth) {
      await _tokenStore.clearCredentials();
      _accessToken = null;
      _expiresAt = null;
      _tokenType = 'Bearer';
      await _authenticateDevice();
      return getSelfStatus(endpoint: endpoint);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'GET request failed',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
    return DeviceSelfStatus.fromJson(
      ApiServiceSupport.decodeObject(response.body),
    );
  }
}

