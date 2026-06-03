import 'package:eyesonly/l10n/app_localizations.dart';
import 'package:eyesonly/screens/main_manager/login_page.dart';
import 'package:eyesonly/screens/main_manager/select_capture_group_page.dart';
import 'package:eyesonly/services/api_exception.dart';
import 'package:eyesonly/services/group_display_service.dart';
import 'package:eyesonly/services/manager/api_service.dart';
import 'package:eyesonly/services/manager/device_registration_service.dart';
import 'package:eyesonly/services/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SelectCaptureGroupPage', () {
    testWidgets(
      'recovers from expired session after one successful login',
      (WidgetTester tester) async {
        final _FakeSettingsStore settingsStore = _FakeSettingsStore();
        final _FakeManagerApiService managerApiService =
            _FakeManagerApiService();

        await tester.pumpWidget(
          _buildTestApp(
            SelectCaptureGroupPage(
              baseUrl: 'http://example.com',
              settingsStore: settingsStore,
              managerApiService: managerApiService,
              deviceRegistrationService: _FakeDeviceRegistrationService(),
              groupDisplayService: _FakeGroupDisplayService(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(LoginPage), findsOneWidget);

        final BuildContext loginContext = tester.element(find.byType(LoginPage));
        Navigator.of(loginContext).pop(true);
        await tester.pumpAndSettle();

        expect(find.byType(LoginPage), findsNothing);
        expect(find.text('Alpha'), findsOneWidget);
        expect(find.text('Beta'), findsOneWidget);
        expect(managerApiService.getManagerGroupsCallCount, 2);
        expect(settingsStore.savedUsernames, isEmpty);
      },
    );
  });
}

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

class _FakeSettingsStore extends SettingsStore {
  final List<String?> savedUsernames = <String?>[];

  @override
  Future<AppSettings> load() async {
    return const AppSettings(
      managerModeEnabled: true,
      useBiometricLock: false,
      darkMode: false,
      pushNotificationsEnabled: false,
      managerServerURL: 'http://example.com',
      lastLoggedInUsername: 'manager',
      deviceServerURLs: <String>['http://example.com'],
      organizations: <AppOrganization>[
        AppOrganization(
          id: 'org-1',
          name: 'Example Org',
          apiUrl: 'http://example.com',
        ),
      ],
    );
  }

  @override
  Future<void> saveLastLoggedInUsername(String? value) async {
    savedUsernames.add(value);
  }
}

class _FakeManagerApiService extends ManagerApiService {
  _FakeManagerApiService() : super(baseUrl: 'http://example.com');

  int getManagerGroupsCallCount = 0;

  @override
  Future<void> hydrateTokens() async {}

  @override
  Future<List<Map<String, dynamic>>> getManagerGroups() async {
    getManagerGroupsCallCount++;
    if (getManagerGroupsCallCount == 1) {
      throw ApiException(
        'Your manager session has expired. Please log in again.',
        statusCode: 401,
      );
    }

    return <Map<String, dynamic>>[
      <String, dynamic>{
        'uuid': 'group-alpha',
        'encrypted_name': 'enc-alpha',
        'name_nonce': 'nonce-alpha',
        'status': 'manager',
      },
      <String, dynamic>{
        'uuid': 'group-beta',
        'encrypted_name': 'enc-beta',
        'name_nonce': 'nonce-beta',
        'status': 'main_manager',
      },
    ];
  }

  @override
  Future<List<MainManagerGroupDevice>> getManagerGroupDevices({
    required String groupId,
  }) async {
    return const <MainManagerGroupDevice>[
      MainManagerGroupDevice(
        deviceIdentifier: 'device-1',
        publicKey: 'pk',
        publicKeyFingerprint: 'fp',
      ),
    ];
  }
}

class _FakeDeviceRegistrationService extends DeviceRegistrationService {
  _FakeDeviceRegistrationService();

  @override
  Future<void> requireCurrentDeviceRegistered({
    required ManagerApiService managerApiService,
  }) async {}

  @override
  Future<String> getCurrentDeviceIdentifier() async => 'device-1';
}

class _FakeGroupDisplayService extends GroupDisplayService {
  _FakeGroupDisplayService();

  @override
  Future<void> syncGroupKeysFromDeviceEndpoint({
    required String baseUrl,
    required Iterable<String> groupIds,
    List<String>? scopes,
  }) async {}

  @override
  Future<String?> tryDecryptGroupName({
    required String groupId,
    required String encryptedName,
    required String nameNonce,
  }) async {
    if (encryptedName == 'enc-alpha') {
      return 'Alpha';
    }
    if (encryptedName == 'enc-beta') {
      return 'Beta';
    }
    return null;
  }
}