import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eyesonly/main.dart' show MyApp;
import 'package:eyesonly/screens/group_detail_page.dart';
import 'package:eyesonly/screens/groups_page.dart';
import 'package:eyesonly/screens/main_manager/login_page.dart';
import 'package:eyesonly/screens/main_manager/select_capture_group_page.dart';
import 'package:eyesonly/services/api_exception.dart';
import 'package:eyesonly/services/device/api_service.dart';
import 'package:eyesonly/services/group_display_service.dart';
import 'package:eyesonly/services/manager/api_service.dart';
import 'package:eyesonly/services/manager/device_registration_service.dart';
import 'package:eyesonly/services/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MyApp lock flow', () {
    testWidgets('unlocks on launch when device auth succeeds', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MyApp(
          initialSettings: const AppSettings(
            managerModeEnabled: false,
            useBiometricLock: true,
            pushNotificationsEnabled: true,
            darkMode: false,
            managerServerURL: null,
            lastLoggedInUsername: null,
            deviceServerURLs: <String>[],
            organizations: <AppOrganization>[],
          ),
          deviceSupportChecker: () async => true,
          deviceAuthenticator: () async => true,
          home: const Scaffold(body: Text('home')),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Eyes Only is locked'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('ignores lifecycle relock while authentication is active', (
      WidgetTester tester,
    ) async {
      final Completer<bool> authCompleter = Completer<bool>();
      int authCalls = 0;

      await tester.pumpWidget(
        MyApp(
          initialSettings: const AppSettings(
            managerModeEnabled: false,
            useBiometricLock: true,
            pushNotificationsEnabled: true,
            darkMode: false,
            managerServerURL: null,
            lastLoggedInUsername: null,
            deviceServerURLs: <String>[],
            organizations: <AppOrganization>[],
          ),
          deviceSupportChecker: () async => true,
          deviceAuthenticator: () {
            authCalls += 1;
            return authCompleter.future;
          },
          home: const Scaffold(body: Text('home')),
        ),
      );

      await tester.pump();
      expect(find.text('Unlocking...'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      authCompleter.complete(true);
      await tester.pumpAndSettle();

      expect(authCalls, 1);
      expect(find.text('Eyes Only is locked'), findsNothing);
    });

    testWidgets('shows unsupported-device message when auth is unavailable', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MyApp(
          initialSettings: const AppSettings(
            managerModeEnabled: false,
            useBiometricLock: true,
            pushNotificationsEnabled: true,
            darkMode: false,
            managerServerURL: null,
            lastLoggedInUsername: null,
            deviceServerURLs: <String>[],
            organizations: <AppOrganization>[],
          ),
          deviceSupportChecker: () async => false,
          home: const Scaffold(body: Text('home')),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Eyes Only is locked'), findsOneWidget);
      expect(find.text('No device authentication is available.'), findsOneWidget);
    });
  });

  group('GroupsPage', () {
    testWidgets('loads renamed organization and decrypted groups', (
      WidgetTester tester,
    ) async {
      final FakeSettingsStore settingsStore = FakeSettingsStore(
        const AppSettings(
          managerModeEnabled: true,
          useBiometricLock: false,
          pushNotificationsEnabled: true,
          darkMode: false,
          managerServerURL: 'http://manager',
          lastLoggedInUsername: 'tom',
          deviceServerURLs: <String>['http://org'],
          organizations: <AppOrganization>[
            AppOrganization(id: 'org-1', name: 'Old Org', apiUrl: 'http://org'),
          ],
        ),
      );
      final FakeGroupDisplayService groupDisplayService = FakeGroupDisplayService(
        namesByGroupId: <String, String>{'group-1': 'Alpha'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GroupsPage(
            settingsStore: settingsStore,
            groupDisplayService: groupDisplayService,
            organizationNameFetcher: (_) async => 'New Org',
            groupsFetcher: (_) async => const <DeviceGroup>[
              DeviceGroup(
                uuid: 'group-1',
                encryptedName: 'enc',
                nameNonce: 'nonce',
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('New Org'), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Create Group'), findsOneWidget);
      expect(settingsStore.savedOrganizations.single.name, 'New Org');
      expect(groupDisplayService.syncedGroupIds.single, <String>['group-1']);
    });

    testWidgets('suppresses unauthorized device errors as empty groups', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GroupsPage(
            settingsStore: FakeSettingsStore(
              const AppSettings(
                managerModeEnabled: false,
                useBiometricLock: false,
                pushNotificationsEnabled: true,
                darkMode: false,
                managerServerURL: null,
                lastLoggedInUsername: null,
                deviceServerURLs: <String>['http://org'],
                organizations: <AppOrganization>[
                  AppOrganization(id: 'org-1', name: 'Org', apiUrl: 'http://org'),
                ],
              ),
            ),
            groupsFetcher: (_) async {
              throw ApiException(
                'This device could not be authenticated with this server.',
                statusCode: 401,
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No groups'), findsOneWidget);
      expect(
        find.textContaining('could not be authenticated', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('manager mode can open the share organization QR screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GroupsPage(
            settingsStore: FakeSettingsStore(
              const AppSettings(
                managerModeEnabled: true,
                useBiometricLock: false,
                pushNotificationsEnabled: true,
                darkMode: false,
                managerServerURL: null,
                lastLoggedInUsername: null,
                deviceServerURLs: <String>['http://org'],
                organizations: <AppOrganization>[
                  AppOrganization(id: 'org-1', name: 'Org', apiUrl: 'http://org'),
                ],
              ),
            ),
            organizationNameFetcher: (_) async => 'Org',
            groupsFetcher: (_) async => const <DeviceGroup>[],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Share Organization'), findsOneWidget);

      await tester.tap(find.text('Share Organization'));
      await tester.pumpAndSettle();

      expect(find.text('Share Organization'), findsOneWidget);
      expect(
        find.text('Have the other device scan this QR code to add this organization.'),
        findsOneWidget,
      );
      expect(find.text('http://org'), findsOneWidget);
    });
  });

  group('GroupDetailPage', () {
    testWidgets('manager can reveal identifiers and remove a device', (
      WidgetTester tester,
    ) async {
      final FakeManagerApiService managerApiService = FakeManagerApiService(
        devices: <MainManagerGroupDevice>[
          const MainManagerGroupDevice(
            deviceIdentifier: 'device-1',
            encryptedMemberName: 'enc-alice',
            publicKey: 'key',
            publicKeyFingerprint: 'fingerprint',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GroupDetailPage(
            groupId: 'group-1',
            groupName: 'Alpha',
            baseUrl: 'http://org',
            organizationName: 'Org',
            isManager: true,
            managerApiService: managerApiService,
            groupDisplayService: FakeGroupDisplayService(
              namesByGroupId: const <String, String>{},
              memberNamesByGroupId: <String, Map<String, String>>{
                'group-1': <String, String>{'enc-alice': 'Alice'},
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('device-1'), findsNothing);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.text('device-1'), findsOneWidget);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(managerApiService.removedDeviceIds, <String>['device-1']);
      expect(find.text('Alice'), findsNothing);
      expect(find.text('Removed Alice from the group.'), findsOneWidget);
    });

    testWidgets('manager shows a clean fallback label when owner-name decryption fails', (
      WidgetTester tester,
    ) async {
      final FakeManagerApiService managerApiService = FakeManagerApiService(
        devices: <MainManagerGroupDevice>[
          const MainManagerGroupDevice(
            deviceIdentifier: 'device-1',
            encryptedMemberName: 'enc-bad',
            publicKey: 'key',
            publicKeyFingerprint: 'fingerprint',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GroupDetailPage(
            groupId: 'group-1',
            groupName: 'Alpha',
            baseUrl: 'http://org',
            organizationName: 'Org',
            isManager: true,
            managerApiService: managerApiService,
            groupDisplayService: FakeGroupDisplayService(
              namesByGroupId: const <String, String>{},
              memberNamesByGroupId: const <String, Map<String, String>>{},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Decryption failed'), findsOneWidget);
      expect(find.text('enc-bad'), findsNothing);
    });

    testWidgets('member can leave a group', (WidgetTester tester) async {
      final FakeDeviceApiService deviceApiService = FakeDeviceApiService();
      bool? didLeave;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: FilledButton(
                  onPressed: () async {
                    didLeave = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) => GroupDetailPage(
                          groupId: 'group-1',
                          groupName: 'Alpha',
                          baseUrl: 'http://org',
                          organizationName: 'Org',
                          isManager: false,
                          deviceApiService: deviceApiService,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave Group'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
      await tester.pumpAndSettle();

      expect(deviceApiService.leftGroupIds, <String>['group-1']);
      expect(didLeave, isTrue);
    });
  });

  group('SelectCaptureGroupPage', () {
    testWidgets('auto-selects a single allowed group when the device is registered', (
      WidgetTester tester,
    ) async {
      final FakeManagerApiService managerApiService = FakeManagerApiService(
        managerGroups: <Map<String, dynamic>>[
          <String, dynamic>{
            'uuid': 'group-1',
            'encrypted_name': 'enc-alpha',
            'name_nonce': 'nonce-alpha',
            'status': 'manager',
          },
          <String, dynamic>{
            'uuid': 'group-2',
            'encrypted_name': 'enc-beta',
            'name_nonce': 'nonce-beta',
            'status': 'viewer',
          },
        ],
      );
      final FakeDeviceRegistrationService registrationService =
          FakeDeviceRegistrationService();
      final List<String> selected = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => SelectCaptureGroupPage(
                          baseUrl: 'http://manager',
                          settingsStore: FakeSettingsStore(
                            const AppSettings(
                              managerModeEnabled: true,
                              useBiometricLock: false,
                              pushNotificationsEnabled: true,
                              darkMode: false,
                              managerServerURL: 'http://manager',
                              lastLoggedInUsername: 'tom',
                              deviceServerURLs: <String>[],
                              organizations: <AppOrganization>[],
                            ),
                          ),
                          managerApiService: managerApiService,
                          deviceRegistrationService: registrationService,
                          groupDisplayService: FakeGroupDisplayService(
                            namesByGroupId: <String, String>{'group-1': 'Alpha'},
                          ),
                          onGroupSelected: (String groupId, String groupName) async {
                            selected
                              ..add(groupId)
                              ..add(groupName);
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(selected, <String>['group-1', 'Alpha']);
      expect(registrationService.requireCurrentDeviceRegisteredCalls, 1);
      expect(registrationService.ensureRegisteredCalls, 0);
      expect(find.text('Take Picture'), findsNothing);
    });
  });

  group('LoginPage', () {
    testWidgets('prompts instead of auto-registering an unregistered manager device', (
      WidgetTester tester,
    ) async {
      final FakeSettingsStore settingsStore = FakeSettingsStore(
        const AppSettings(
          managerModeEnabled: true,
          useBiometricLock: false,
          pushNotificationsEnabled: true,
          darkMode: false,
          managerServerURL: 'http://manager',
          lastLoggedInUsername: null,
          deviceServerURLs: <String>[],
          organizations: <AppOrganization>[],
        ),
      );
      final FakeDeviceRegistrationService registrationService =
          FakeDeviceRegistrationService(
            isCurrentDeviceRegisteredValue: false,
            hasExistingManagerOwnedDeviceValue: true,
          );
      final FakeManagerApiService managerApiService = FakeManagerApiService();
      final FakeDeviceApiService deviceApiService = FakeDeviceApiService(
        selfStatus: const DeviceSelfStatus(
          deviceIdentifier: 'device-2',
          isRegistered: false,
          organizationName: 'Org',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            settingsStore: settingsStore,
            deviceRegistrationService: registrationService,
            managerApiServiceBuilder: (_) => managerApiService,
            deviceApiServiceBuilder: (_) => deviceApiService,
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'tom');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret');
      await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
      await tester.pumpAndSettle();

      expect(find.text('Register This Device'), findsOneWidget);
      expect(registrationService.isCurrentDeviceRegisteredCalls, 1);
      expect(registrationService.hasExistingManagerOwnedDeviceCalls, 1);
      expect(registrationService.ensureRegisteredCalls, 0);
      expect(registrationService.ensureCurrentDeviceAddedCalls, 0);
      expect(managerApiService.loginCalls, 1);
    });

    testWidgets('auto-registers the first manager device when no owned device exists yet', (
      WidgetTester tester,
    ) async {
      final FakeSettingsStore settingsStore = FakeSettingsStore(
        const AppSettings(
          managerModeEnabled: true,
          useBiometricLock: false,
          pushNotificationsEnabled: true,
          darkMode: false,
          managerServerURL: 'http://manager',
          lastLoggedInUsername: null,
          deviceServerURLs: <String>[],
          organizations: <AppOrganization>[],
        ),
      );
      final FakeDeviceRegistrationService registrationService =
          FakeDeviceRegistrationService(
            isCurrentDeviceRegisteredValue: false,
            hasExistingManagerOwnedDeviceValue: false,
          );
      final FakeManagerApiService managerApiService = FakeManagerApiService();
      final FakeDeviceApiService deviceApiService = FakeDeviceApiService(
        selfStatus: const DeviceSelfStatus(
          deviceIdentifier: 'device-1',
          isRegistered: false,
          organizationName: 'Org',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            settingsStore: settingsStore,
            deviceRegistrationService: registrationService,
            managerApiServiceBuilder: (_) => managerApiService,
            deviceApiServiceBuilder: (_) => deviceApiService,
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'tom');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret');
      await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
      await tester.pumpAndSettle();

      expect(find.text('Register This Device'), findsNothing);
      expect(registrationService.ensureRegisteredCalls, 1);
      expect(registrationService.hasExistingManagerOwnedDeviceCalls, 1);
      expect(managerApiService.loginCalls, 1);
    });
  });
}

class FakeSettingsStore extends SettingsStore {
  FakeSettingsStore(this.settings);

  AppSettings settings;
  List<AppOrganization> savedOrganizations = <AppOrganization>[];
  List<String>? savedDeviceServerUrls;
  String? savedLastLoggedInUsername;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> saveOrganizations(List<AppOrganization> organizations) async {
    savedOrganizations = organizations;
    settings = AppSettings(
      managerModeEnabled: settings.managerModeEnabled,
      useBiometricLock: settings.useBiometricLock,
      pushNotificationsEnabled: settings.pushNotificationsEnabled,
      darkMode: settings.darkMode,
      managerServerURL: settings.managerServerURL,
      lastLoggedInUsername: settings.lastLoggedInUsername,
      deviceServerURLs: organizations.map((AppOrganization org) => org.apiUrl).toList(),
      organizations: organizations,
    );
  }

  @override
  Future<void> upsertOrganization(AppOrganization organization) async {
    final List<AppOrganization> organizations =
        List<AppOrganization>.from(settings.organizations);
    final int existingIndex = organizations.indexWhere(
      (AppOrganization current) => current.apiUrl == organization.apiUrl,
    );
    if (existingIndex >= 0) {
      organizations[existingIndex] = organization;
    } else {
      organizations.add(organization);
    }
    await saveOrganizations(organizations);
  }

  @override
  Future<void> saveDeviceServerURLs(List<String> urls) async {
    savedDeviceServerUrls = List<String>.from(urls);
    settings = AppSettings(
      managerModeEnabled: settings.managerModeEnabled,
      useBiometricLock: settings.useBiometricLock,
      pushNotificationsEnabled: settings.pushNotificationsEnabled,
      darkMode: settings.darkMode,
      managerServerURL: settings.managerServerURL,
      lastLoggedInUsername: settings.lastLoggedInUsername,
      deviceServerURLs: List<String>.from(urls),
      organizations: settings.organizations,
    );
  }

  @override
  Future<void> saveLastLoggedInUsername(String? value) async {
    savedLastLoggedInUsername = value;
    settings = AppSettings(
      managerModeEnabled: settings.managerModeEnabled,
      useBiometricLock: settings.useBiometricLock,
      pushNotificationsEnabled: settings.pushNotificationsEnabled,
      darkMode: settings.darkMode,
      managerServerURL: settings.managerServerURL,
      lastLoggedInUsername: value,
      deviceServerURLs: settings.deviceServerURLs,
      organizations: settings.organizations,
    );
  }
}

class FakeGroupDisplayService extends GroupDisplayService {
  FakeGroupDisplayService({
    required this.namesByGroupId,
    this.memberNamesByGroupId = const <String, Map<String, String>>{},
  });

  final Map<String, String> namesByGroupId;
  final Map<String, Map<String, String>> memberNamesByGroupId;
  final List<List<String>> syncedGroupIds = <List<String>>[];

  @override
  Future<void> syncGroupKeysFromDeviceEndpoint({
    required String baseUrl,
    required Iterable<String> groupIds,
    List<String>? scopes,
  }) async {
    syncedGroupIds.add(groupIds.toList());
  }

  @override
  Future<String?> tryDecryptGroupName({
    required String groupId,
    required String encryptedName,
    required String nameNonce,
  }) async {
    return namesByGroupId[groupId];
  }

  @override
  Future<String?> tryDecryptMemberName({
    required String groupId,
    required String encryptedMemberName,
  }) async {
    return memberNamesByGroupId[groupId]?[encryptedMemberName];
  }
}

class FakeManagerApiService extends ManagerApiService {
  FakeManagerApiService({
    this.devices = const <MainManagerGroupDevice>[],
    this.managerOwnedDevicesByGroup = const <String, List<MainManagerGroupDevice>>{},
    this.managerGroups = const <Map<String, dynamic>>[],
  }) : super(baseUrl: 'http://example.test');

  List<MainManagerGroupDevice> devices;
  final Map<String, List<MainManagerGroupDevice>> managerOwnedDevicesByGroup;
  final List<Map<String, dynamic>> managerGroups;
  final List<String> removedDeviceIds = <String>[];
  int loginCalls = 0;

  @override
  Future<void> hydrateTokens() async {}

  @override
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    String endpoint = '',
  }) async {
    loginCalls += 1;
    return <String, dynamic>{'access': 'token', 'refresh': 'refresh'};
  }

  @override
  Future<List<MainManagerGroupDevice>> getMainManagerGroupDevices({
    required String groupId,
  }) async {
    return devices;
  }

  @override
  Future<List<Map<String, dynamic>>> getManagerGroups() async {
    return managerGroups;
  }

  @override
  Future<List<MainManagerGroupDevice>> getManagerGroupDevices({
    required String groupId,
  }) async {
    return managerOwnedDevicesByGroup[groupId] ?? const <MainManagerGroupDevice>[];
  }

  @override
  Future<void> removeDeviceFromGroup({
    required String deviceIdentifier,
    required String groupId,
    String endpoint = '',
  }) async {
    removedDeviceIds.add(deviceIdentifier);
    devices = devices
        .where((MainManagerGroupDevice device) => device.deviceIdentifier != deviceIdentifier)
        .toList();
  }
}

class FakeDeviceApiService extends DeviceApiService {
  FakeDeviceApiService({this.selfStatus}) : super(baseUrl: 'http://example.test');

  final List<String> leftGroupIds = <String>[];
  final DeviceSelfStatus? selfStatus;

  @override
  Future<DeviceSelfStatus> getSelfStatus({String endpoint = ''}) async {
    return selfStatus ??
        const DeviceSelfStatus(
          deviceIdentifier: 'device-1',
          isRegistered: true,
        );
  }

  @override
  Future<void> leaveGroup({
    required String groupId,
    String endpoint = '',
  }) async {
    leftGroupIds.add(groupId);
  }
}

class FakeDeviceRegistrationService extends DeviceRegistrationService {
  FakeDeviceRegistrationService({
    this.isCurrentDeviceRegisteredValue = true,
    this.hasExistingManagerOwnedDeviceValue = false,
  });

  int ensureRegisteredCalls = 0;
  int ensureCurrentDeviceAddedCalls = 0;
  int isCurrentDeviceRegisteredCalls = 0;
  int requireCurrentDeviceRegisteredCalls = 0;
  int hasExistingManagerOwnedDeviceCalls = 0;
  final bool isCurrentDeviceRegisteredValue;
  final bool hasExistingManagerOwnedDeviceValue;

  @override
  Future<void> ensureRegistered({
    required ManagerApiService managerApiService,
    required String username,
  }) async {
    ensureRegisteredCalls += 1;
  }

  @override
  Future<void> ensureCurrentDeviceAddedToMainManagerGroups({
    required ManagerApiService managerApiService,
    String? username,
  }) async {
    ensureCurrentDeviceAddedCalls += 1;
  }

  @override
  Future<bool> isCurrentDeviceRegistered({
    required ManagerApiService managerApiService,
  }) async {
    isCurrentDeviceRegisteredCalls += 1;
    return isCurrentDeviceRegisteredValue;
  }

  @override
  Future<bool> hasExistingManagerOwnedDevice({
    required ManagerApiService managerApiService,
  }) async {
    hasExistingManagerOwnedDeviceCalls += 1;
    return hasExistingManagerOwnedDeviceValue;
  }

  @override
  Future<void> requireCurrentDeviceRegistered({
    required ManagerApiService managerApiService,
  }) async {
    requireCurrentDeviceRegisteredCalls += 1;
    if (!isCurrentDeviceRegisteredValue) {
      throw ApiException(
        DeviceRegistrationService.managerDeviceRegistrationRequiredMessage,
      );
    }
  }
}