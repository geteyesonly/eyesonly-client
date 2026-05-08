import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eyesonly/screens/add_organization_page.dart';
import 'package:eyesonly/screens/settings_page.dart';
import 'package:eyesonly/services/secure_decrypted_image_cache.dart';
import 'package:eyesonly/services/settings_store.dart';

void main() {
  group('AddOrganizationPage', () {
    testWidgets('validates that the API URL is required', (
      WidgetTester tester,
    ) async {
      await _pumpPushedPage(
        tester,
        AddOrganizationPage(
          settingsStore: FakeSettingsStore(),
          statusFetcher: (_) async => (orgName: null, error: null),
        ),
      );

      await tester.tap(find.text('Check Organization'));
      await tester.pump();

      expect(find.text('API URL is required'), findsOneWidget);
    });

    testWidgets('shows an inline server error when the status check fails', (
      WidgetTester tester,
    ) async {
      await _pumpPushedPage(
        tester,
        AddOrganizationPage(
          settingsStore: FakeSettingsStore(),
          statusFetcher: (_) async => (
            orgName: null,
            error: 'Could not reach the server. Please check the URL.',
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField),
        'http://localhost:8080',
      );
      await tester.tap(find.text('Check Organization'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not reach the server. Please check the URL.'),
        findsOneWidget,
      );
    });

    testWidgets('checks, confirms, and saves an organization', (
      WidgetTester tester,
    ) async {
      final FakeSettingsStore settingsStore = FakeSettingsStore();

      await _pumpPushedPage(
        tester,
        AddOrganizationPage(
          settingsStore: settingsStore,
          statusFetcher: (_) async => (
            orgName: 'Local Dev Server',
            error: null,
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField),
        'http://localhost:8080',
      );
      await tester.tap(find.text('Check Organization'));
      await tester.pumpAndSettle();

      expect(find.text('Local Dev Server'), findsOneWidget);
      expect(find.text('Add this organization?'), findsOneWidget);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Open Test Page'), findsOneWidget);
      expect(settingsStore.savedOrganizations, hasLength(1));
      expect(settingsStore.savedOrganizations.single.name, 'Local Dev Server');
      expect(settingsStore.savedOrganizations.single.apiUrl, 'http://localhost:8080');
    });
  });

  group('SettingsPage', () {
    testWidgets('reveals manager settings and auto-selects the sole organization', (
      WidgetTester tester,
    ) async {
      final AppOrganization organization = AppOrganization(
        id: 'org-1',
        name: 'Local Org',
        apiUrl: 'http://localhost:8080',
      );
      final FakeSettingsStore settingsStore = FakeSettingsStore(
        initialSettings: AppSettings(
          managerModeEnabled: false,
          useBiometricLock: false,
          pushNotificationsEnabled: true,
          darkMode: false,
          managerServerURL: null,
          lastLoggedInUsername: null,
          deviceServerURLs: const <String>[],
          organizations: <AppOrganization>[organization],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(settingsStore: settingsStore),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Manager Settings'), findsNothing);

      await tester.scrollUntilVisible(find.text('Manager Mode'), 200);
      await tester.tap(find.text('Manager Mode'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Manager Settings'), 200);
      expect(find.text('Manager Settings'), findsOneWidget);
      expect(settingsStore.savedManagerModeEnabled, isTrue);
      expect(settingsStore.savedManagerServerURL, 'http://localhost:8080');
    });

    testWidgets('deletes the image cache after confirmation', (
      WidgetTester tester,
    ) async {
      final FakeImageCache imageCache = FakeImageCache();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(
            settingsStore: FakeSettingsStore(),
            imageCache: imageCache,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Delete Image Cache'), 200);
      await tester.tap(find.text('Delete Image Cache'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Delete all locally cached images from this device?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete Cache'));
      await tester.pumpAndSettle();

      expect(imageCache.clearCalled, isTrue);
      expect(find.text('Image cache deleted.'), findsOneWidget);
    });

    testWidgets('confirms and runs the reset action', (
      WidgetTester tester,
    ) async {
      bool resetCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(
            settingsStore: FakeSettingsStore(),
            resetAppAction: () async {
              resetCalled = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Reset App'), 200);
      await tester.tap(find.text('Reset App'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Warning: Resetting the app will remove local keys'),
        findsOneWidget,
      );

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(resetCalled, isTrue);
    });
  });
}

Future<void> _pumpPushedPage(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (BuildContext context) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => page,
                    ),
                  );
                },
                child: const Text('Open Test Page'),
              ),
            ),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('Open Test Page'));
  await tester.pumpAndSettle();
}

class FakeSettingsStore extends SettingsStore {
  FakeSettingsStore({AppSettings? initialSettings})
    : _settings = initialSettings ?? AppSettings.defaults;

  static const Object _unset = Object();

  AppSettings _settings;
  List<AppOrganization> savedOrganizations = <AppOrganization>[];
  bool? savedManagerModeEnabled;
  bool? savedDarkMode;
  bool? savedUseBiometricLock;
  String? savedManagerServerURL;

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> saveOrganizations(List<AppOrganization> organizations) async {
    savedOrganizations = List<AppOrganization>.from(organizations);
    _settings = _copyWith(
      organizations: savedOrganizations,
      deviceServerURLs: organizations
          .map((AppOrganization organization) => organization.apiUrl)
          .toSet()
          .toList(),
    );
  }

  @override
  Future<void> saveManagerModeEnabled(bool value) async {
    savedManagerModeEnabled = value;
    _settings = _copyWith(managerModeEnabled: value);
  }

  @override
  Future<void> saveDarkMode(bool value) async {
    savedDarkMode = value;
    _settings = _copyWith(darkMode: value);
  }

  @override
  Future<void> saveUseBiometricLock(bool value) async {
    savedUseBiometricLock = value;
    _settings = _copyWith(useBiometricLock: value);
  }

  @override
  Future<void> saveManagerServerURL(String? value) async {
    savedManagerServerURL = value;
    _settings = _copyWith(managerServerURL: value);
  }

  AppSettings _copyWith({
    bool? managerModeEnabled,
    bool? useBiometricLock,
    bool? darkMode,
    Object? managerServerURL = _unset,
    Object? lastLoggedInUsername = _unset,
    List<String>? deviceServerURLs,
    List<AppOrganization>? organizations,
  }) {
    return AppSettings(
      managerModeEnabled: managerModeEnabled ?? _settings.managerModeEnabled,
      useBiometricLock: useBiometricLock ?? _settings.useBiometricLock,
      pushNotificationsEnabled: _settings.pushNotificationsEnabled,
      darkMode: darkMode ?? _settings.darkMode,
      managerServerURL: identical(managerServerURL, _unset)
          ? _settings.managerServerURL
          : managerServerURL as String?,
      lastLoggedInUsername: identical(lastLoggedInUsername, _unset)
          ? _settings.lastLoggedInUsername
          : lastLoggedInUsername as String?,
      deviceServerURLs: deviceServerURLs ?? _settings.deviceServerURLs,
      organizations: organizations ?? _settings.organizations,
    );
  }
}

class FakeImageCache extends SecureDecryptedImageCache {
  bool clearCalled = false;

  @override
  Future<void> clear() async {
    clearCalled = true;
  }
}
