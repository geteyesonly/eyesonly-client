import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:eyesonly/l10n/app_localizations.dart';
import 'package:eyesonly/screens/main_manager/groups/group_push_notification_page.dart';
import 'package:eyesonly/screens/home_page.dart';
import 'package:eyesonly/screens/add_organization_page.dart';
import 'package:eyesonly/screens/settings_page.dart';
import 'package:eyesonly/services/api_exception.dart';
import 'package:eyesonly/services/device_encrypted_image_feed_service.dart';
import 'package:eyesonly/services/secure_encrypted_image_blob_cache.dart';
import 'package:eyesonly/services/settings_store.dart';

Widget buildTestApp(Widget child) {
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

void main() {
  group('MyHomePage', () {
    testWidgets('shows join group when device is not in any groups', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          MyHomePage(
            title: 'Eyes Only',
            settingsStore: FakeSettingsStore(
              const AppSettings(
                managerModeEnabled: false,
                useBiometricLock: false,
                darkMode: false,
                pushNotificationsEnabled: false,
                managerServerURL: null,
                lastLoggedInUsername: null,
                deviceServerURLs: <String>[],
                organizations: <AppOrganization>[],
              ),
            ),
            membershipChecker: (_) async => false,
            imageFeedService: FakeImageFeedService.noop(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('You are not in any groups yet.'), findsOneWidget);
      expect(find.text('Join Group'), findsOneWidget);
    });

    testWidgets('shows startup error when device servers cannot be reached', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          MyHomePage(
            title: 'Eyes Only',
            settingsStore: FakeSettingsStore(
              const AppSettings(
                managerModeEnabled: false,
                useBiometricLock: false,
                darkMode: false,
                pushNotificationsEnabled: false,
                managerServerURL: null,
                lastLoggedInUsername: null,
                deviceServerURLs: <String>['http://org'],
                organizations: <AppOrganization>[
                  AppOrganization(id: 'org-1', name: 'Org', apiUrl: 'http://org'),
                ],
              ),
            ),
            membershipChecker: (_) async => null,
            imageFeedService: FakeImageFeedService.noop(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not reach'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows image feed error for members when feed loading fails', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          MyHomePage(
            title: 'Eyes Only',
            settingsStore: FakeSettingsStore(
              const AppSettings(
                managerModeEnabled: false,
                useBiometricLock: false,
                darkMode: false,
                pushNotificationsEnabled: false,
                managerServerURL: null,
                lastLoggedInUsername: null,
                deviceServerURLs: <String>['http://org'],
                organizations: <AppOrganization>[
                  AppOrganization(id: 'org-1', name: 'Org', apiUrl: 'http://org'),
                ],
              ),
            ),
            membershipChecker: (_) async => true,
            imageFeedService: FakeImageFeedService(
              onLoad: ({required settings, required onUpdate}) async {
                throw ApiException('feed failed');
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('feed failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders progressive feed sections', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          MyHomePage(
            title: 'Eyes Only',
            settingsStore: FakeSettingsStore(
              const AppSettings(
                managerModeEnabled: false,
                useBiometricLock: false,
                darkMode: false,
                pushNotificationsEnabled: false,
                managerServerURL: null,
                lastLoggedInUsername: null,
                deviceServerURLs: <String>['http://org'],
                organizations: <AppOrganization>[
                  AppOrganization(id: 'org-1', name: 'Org', apiUrl: 'http://org'),
                ],
              ),
            ),
            membershipChecker: (_) async => true,
            imageFeedService: FakeImageFeedService(
              onLoad: ({required settings, required onUpdate}) async {
                onUpdate(
                  <DeviceEncryptedImageFeedSection>[
                    DeviceEncryptedImageFeedSection(
                      sectionId: 's1',
                      organizationName: 'Org',
                      groupId: 'group-1',
                      groupName: 'Alpha',
                      days: <DeviceEncryptedImageFeedDay>[
                        DeviceEncryptedImageFeedDay(
                          day: DateTime.utc(2026, 5, 4),
                          items: const <DeviceEncryptedImageFeedItem>[
                            DeviceEncryptedImageFeedItem(
                              imageUuid: 'img-1',
                              isCorrupt: true,
                              isLoading: false,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                  true,
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Org'), findsOneWidget);
      expect(find.text('May 4, 2026'), findsOneWidget);
      expect(find.text('Failed to decrypt image'), findsOneWidget);
    });

    testWidgets('manual refresh reloads the feed once', (
      WidgetTester tester,
    ) async {
      int loadCount = 0;

      await tester.pumpWidget(
        buildTestApp(
          MyHomePage(
            title: 'Eyes Only',
            settingsStore: FakeSettingsStore(
              const AppSettings(
                managerModeEnabled: false,
                useBiometricLock: false,
                darkMode: false,
                pushNotificationsEnabled: false,
                managerServerURL: null,
                lastLoggedInUsername: null,
                deviceServerURLs: <String>['http://org'],
                organizations: <AppOrganization>[
                  AppOrganization(id: 'org-1', name: 'Org', apiUrl: 'http://org'),
                ],
              ),
            ),
            membershipChecker: (_) async => true,
            imageFeedService: FakeImageFeedService(
              onLoad: ({required settings, required onUpdate}) async {
                loadCount++;
                onUpdate(
                  <DeviceEncryptedImageFeedSection>[
                    DeviceEncryptedImageFeedSection(
                      sectionId: 's1',
                      organizationName: 'Org',
                      groupId: 'group-1',
                      groupName: 'Alpha',
                      days: <DeviceEncryptedImageFeedDay>[
                        DeviceEncryptedImageFeedDay(
                          day: DateTime.utc(2026, 5, 4),
                          items: <DeviceEncryptedImageFeedItem>[
                            DeviceEncryptedImageFeedItem(
                              imageUuid: 'img-1',
                              isCorrupt: false,
                              isLoading: false,
                              imageBytes: _transparentImageBytes,
                              baseUrl: 'http://org',
                              groupId: 'group-1',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                  true,
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(loadCount, 1);

      final RefreshIndicator refreshIndicator = tester.widget(
        find.byType(RefreshIndicator),
      );
      await refreshIndicator.onRefresh();
      await tester.pumpAndSettle();

      expect(loadCount, 2);
    });

    testWidgets('unlock event after deferred startup does not reload images', (
      WidgetTester tester,
    ) async {
      int loadCount = 0;
      final ValueNotifier<int> unlockEvents = ValueNotifier<int>(0);
      addTearDown(unlockEvents.dispose);

      await tester.pumpWidget(
        buildTestApp(
          MyHomePage(
            title: 'Eyes Only',
            settingsStore: FakeSettingsStore(
              const AppSettings(
                managerModeEnabled: false,
                useBiometricLock: false,
                darkMode: false,
                pushNotificationsEnabled: false,
                managerServerURL: null,
                lastLoggedInUsername: null,
                deviceServerURLs: <String>['http://org'],
                organizations: <AppOrganization>[
                  AppOrganization(id: 'org-1', name: 'Org', apiUrl: 'http://org'),
                ],
              ),
            ),
            membershipChecker: (_) async => true,
            unlockEvents: unlockEvents,
            deferStartupImageCheckFeedbackUntilUnlock: true,
            imageFeedService: FakeImageFeedService(
              onLoad: ({required settings, required onUpdate}) async {
                loadCount++;
                onUpdate(
                  <DeviceEncryptedImageFeedSection>[
                    DeviceEncryptedImageFeedSection(
                      sectionId: 's1',
                      organizationName: 'Org',
                      groupId: 'group-1',
                      groupName: 'Alpha',
                      days: <DeviceEncryptedImageFeedDay>[
                        DeviceEncryptedImageFeedDay(
                          day: DateTime.utc(2026, 5, 4),
                          items: <DeviceEncryptedImageFeedItem>[
                            DeviceEncryptedImageFeedItem(
                              imageUuid: 'img-1',
                              isCorrupt: false,
                              isLoading: false,
                              imageBytes: _transparentImageBytes,
                              baseUrl: 'http://org',
                              groupId: 'group-1',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                  true,
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(loadCount, 1);

      unlockEvents.value = 1;
      await tester.pumpAndSettle();

      expect(loadCount, 1);
    });

    testWidgets('shows send message icon for managers with images and opens send page', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          MyHomePage(
            title: 'Eyes Only',
            settingsStore: FakeSettingsStore(
              const AppSettings(
                managerModeEnabled: true,
                useBiometricLock: false,
                darkMode: false,
                pushNotificationsEnabled: false,
                managerServerURL: 'http://org',
                lastLoggedInUsername: 'tom',
                deviceServerURLs: <String>['http://org'],
                organizations: <AppOrganization>[
                  AppOrganization(id: 'org-1', name: 'Org', apiUrl: 'http://org'),
                ],
              ),
            ),
            membershipChecker: (_) async => true,
            imageFeedService: FakeImageFeedService(
              onLoad: ({required settings, required onUpdate}) async {
                onUpdate(
                  <DeviceEncryptedImageFeedSection>[
                    DeviceEncryptedImageFeedSection(
                      sectionId: 's1',
                      organizationName: 'Org',
                      groupId: 'group-1',
                      groupName: 'Alpha',
                      days: <DeviceEncryptedImageFeedDay>[
                        DeviceEncryptedImageFeedDay(
                          day: DateTime.utc(2026, 5, 4),
                          items: <DeviceEncryptedImageFeedItem>[
                            DeviceEncryptedImageFeedItem(
                              imageUuid: 'img-1',
                              isCorrupt: false,
                              isLoading: false,
                              imageBytes: _transparentImageBytes,
                              baseUrl: 'http://org',
                              groupId: 'group-1',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                  true,
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byTooltip('Send Message to Group'), findsOneWidget);

      await tester.tap(find.byTooltip('Send Message to Group'));
      await tester.pumpAndSettle();

      expect(find.byType(GroupPushNotificationPage), findsOneWidget);
      expect(find.text('Send Message to Group'), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
    });

    testWidgets('hides send message icon when manager is not logged in', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          MyHomePage(
            title: 'Eyes Only',
            settingsStore: FakeSettingsStore(
              const AppSettings(
                managerModeEnabled: true,
                useBiometricLock: false,
                darkMode: false,
                pushNotificationsEnabled: false,
                managerServerURL: 'http://org',
                lastLoggedInUsername: null,
                deviceServerURLs: <String>['http://org'],
                organizations: <AppOrganization>[
                  AppOrganization(id: 'org-1', name: 'Org', apiUrl: 'http://org'),
                ],
              ),
            ),
            membershipChecker: (_) async => true,
            imageFeedService: FakeImageFeedService(
              onLoad: ({required settings, required onUpdate}) async {
                onUpdate(
                  <DeviceEncryptedImageFeedSection>[
                    DeviceEncryptedImageFeedSection(
                      sectionId: 's1',
                      organizationName: 'Org',
                      groupId: 'group-1',
                      groupName: 'Alpha',
                      days: <DeviceEncryptedImageFeedDay>[
                        DeviceEncryptedImageFeedDay(
                          day: DateTime.utc(2026, 5, 4),
                          items: <DeviceEncryptedImageFeedItem>[
                            DeviceEncryptedImageFeedItem(
                              imageUuid: 'img-1',
                              isCorrupt: false,
                              isLoading: false,
                              imageBytes: _transparentImageBytes,
                              baseUrl: 'http://org',
                              groupId: 'group-1',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                  true,
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byTooltip('Send Message to Group'), findsNothing);
    });

    testWidgets('deletes the current fullscreen image after confirmation', (
      WidgetTester tester,
    ) async {
      String? deletedImageUuid;

      await tester.pumpWidget(
        buildTestApp(
          MyHomePage(
            title: 'Eyes Only',
            settingsStore: FakeSettingsStore(
              const AppSettings(
                managerModeEnabled: false,
                useBiometricLock: false,
                darkMode: false,
                pushNotificationsEnabled: false,
                managerServerURL: null,
                lastLoggedInUsername: null,
                deviceServerURLs: <String>['http://org'],
                organizations: <AppOrganization>[
                  AppOrganization(id: 'org-1', name: 'Org', apiUrl: 'http://org'),
                ],
              ),
            ),
            membershipChecker: (_) async => true,
            imageFeedService: FakeImageFeedService(
              onLoad: ({required settings, required onUpdate}) async {
                onUpdate(
                  <DeviceEncryptedImageFeedSection>[
                    DeviceEncryptedImageFeedSection(
                      sectionId: 's1',
                      organizationName: 'Org',
                      groupId: 'group-1',
                      groupName: 'Alpha',
                      days: <DeviceEncryptedImageFeedDay>[
                        DeviceEncryptedImageFeedDay(
                          day: DateTime.utc(2026, 5, 4),
                          items: <DeviceEncryptedImageFeedItem>[
                            DeviceEncryptedImageFeedItem(
                              imageUuid: 'img-1',
                              isCorrupt: false,
                              isLoading: false,
                              imageBytes: _transparentImageBytes,
                              caption: 'Secret image',
                              baseUrl: 'http://org',
                              groupId: 'group-1',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                  true,
                );
              },
              onDelete: (DeviceEncryptedImageFeedItem item) async {
                deletedImageUuid = item.imageUuid;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(Image).first);
      await tester.tap(find.byType(Image).first);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Delete image'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete image'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Image'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(deletedImageUuid, 'img-1');
      expect(find.text('Image deleted.'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
      expect(find.byTooltip('Delete image'), findsNothing);
    });

    testWidgets('opens add organization and then groups when join group is tapped', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          MyHomePage(
            title: 'Eyes Only',
            settingsStore: FakeSettingsStore(
              const AppSettings(
                managerModeEnabled: false,
                useBiometricLock: false,
                darkMode: false,
                pushNotificationsEnabled: false,
                managerServerURL: null,
                lastLoggedInUsername: null,
                deviceServerURLs: <String>[],
                organizations: <AppOrganization>[],
              ),
            ),
            membershipChecker: (_) async => false,
            imageFeedService: FakeImageFeedService.noop(),
            addOrganizationPageBuilder: (_) => const _AutoPopPage(result: true),
            groupsPageBuilder: (_) => const Scaffold(body: Text('Groups target')),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Join Group'));
      await tester.pumpAndSettle();

      expect(find.text('Groups target'), findsOneWidget);
    });

    testWidgets('join group flow auto-selects the first organization as manager server when manager mode is enabled', (
      WidgetTester tester,
    ) async {
      final FakeSettingsStore settingsStore = FakeSettingsStore(
        const AppSettings(
          managerModeEnabled: true,
          useBiometricLock: false,
          darkMode: false,
          pushNotificationsEnabled: false,
          managerServerURL: null,
          lastLoggedInUsername: null,
          deviceServerURLs: <String>[],
          organizations: <AppOrganization>[],
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          MyHomePage(
            title: 'Eyes Only',
            settingsStore: settingsStore,
            membershipChecker: (_) async => false,
            imageFeedService: FakeImageFeedService.noop(),
            addOrganizationPageBuilder: (_) => _AutoPopActionPage(
              action: () async {
                await settingsStore.saveOrganizations(
                  const <AppOrganization>[
                    AppOrganization(
                      id: 'org-1',
                      name: 'Org',
                      apiUrl: 'http://org',
                    ),
                  ],
                );
              },
              result: true,
            ),
            groupsPageBuilder: (_) => const Scaffold(body: Text('Groups target')),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Join Group'));
      await tester.pumpAndSettle();

      expect(settingsStore.savedManagerServerURL, 'http://org');
      expect(find.text('Groups target'), findsOneWidget);
    });

    testWidgets('shows manager-server snackbar when capture is available but not configured', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          MyHomePage(
            title: 'Eyes Only',
            settingsStore: FakeSettingsStore(
              const AppSettings(
                managerModeEnabled: true,
                useBiometricLock: false,
                darkMode: false,
                pushNotificationsEnabled: false,
                managerServerURL: null,
                lastLoggedInUsername: 'tom',
                deviceServerURLs: <String>[],
                organizations: <AppOrganization>[],
              ),
            ),
            membershipChecker: (_) async => false,
            imageFeedService: FakeImageFeedService.noop(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Take Picture'));
      await tester.pumpAndSettle();

      expect(find.text('Manager server URL is not set.'), findsOneWidget);
    });
  });

  group('AddOrganizationPage edge cases', () {
    testWidgets('rejects duplicate API URLs', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          AddOrganizationPage(
            settingsStore: FakeSettingsStore(
              const AppSettings(
                managerModeEnabled: false,
                useBiometricLock: false,
                darkMode: false,
                pushNotificationsEnabled: false,
                managerServerURL: null,
                lastLoggedInUsername: null,
                deviceServerURLs: <String>['http://localhost:8080'],
                organizations: <AppOrganization>[
                  AppOrganization(
                    id: 'org-1',
                    name: 'Local',
                    apiUrl: 'http://localhost:8080',
                  ),
                ],
              ),
            ),
            statusFetcher: (_) async => (orgName: 'Local', error: null),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'http://localhost:8080');
      await tester.tap(find.text('Check Organization'));
      await tester.pump();

      expect(find.text('This API URL has already been added'), findsOneWidget);
    });

    testWidgets('canceling confirmation does not save the organization', (
      WidgetTester tester,
    ) async {
      final FakeSettingsStore settingsStore = FakeSettingsStore(AppSettings.defaults);

      await tester.pumpWidget(
        buildTestApp(
          AddOrganizationPage(
            settingsStore: settingsStore,
            statusFetcher: (_) async => (orgName: 'Local', error: null),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'http://localhost:8080');
      await tester.tap(find.text('Check Organization'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Add this organization?'), findsNothing);
      expect(settingsStore.savedOrganizations, isEmpty);
    });

    testWidgets('invalid QR scan shows a message', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          AddOrganizationPage(
            settingsStore: FakeSettingsStore(AppSettings.defaults),
            scanQrCode: (_) async => 'not a url',
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan QR Code'));
      await tester.pumpAndSettle();

      expect(
        find.text('The scanned QR code did not contain a valid API URL.'),
        findsOneWidget,
      );
      expect(find.text('not a url'), findsNothing);
    });
  });

  group('SettingsPage edge cases', () {
    testWidgets('shows an error when image cache deletion fails', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          SettingsPage(
            settingsStore: FakeSettingsStore(AppSettings.defaults),
            imageCache: ThrowingImageCache(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Delete Encrypted Image Cache'),
        200,
      );
      await tester.tap(find.text('Delete Encrypted Image Cache'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Cache'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not delete image cache'),
        findsOneWidget,
      );
    });
  });
}

class FakeSettingsStore extends SettingsStore {
  FakeSettingsStore(this.settings);

  AppSettings settings;
  List<AppOrganization> savedOrganizations = <AppOrganization>[];
  bool? savedUseBiometricLock;
  String? savedManagerServerURL;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> saveOrganizations(List<AppOrganization> organizations) async {
    savedOrganizations = List<AppOrganization>.from(organizations);
    settings = AppSettings(
      managerModeEnabled: settings.managerModeEnabled,
      useBiometricLock: settings.useBiometricLock,
      darkMode: settings.darkMode,
      pushNotificationsEnabled: settings.pushNotificationsEnabled,
      managerServerURL: settings.managerServerURL,
      lastLoggedInUsername: settings.lastLoggedInUsername,
      deviceServerURLs: organizations.map((AppOrganization org) => org.apiUrl).toList(),
      organizations: organizations,
    );
  }

  @override
  Future<void> saveUseBiometricLock(bool value) async {
    savedUseBiometricLock = value;
    settings = AppSettings(
      managerModeEnabled: settings.managerModeEnabled,
      useBiometricLock: value,
      darkMode: settings.darkMode,
      pushNotificationsEnabled: settings.pushNotificationsEnabled,
      managerServerURL: settings.managerServerURL,
      lastLoggedInUsername: settings.lastLoggedInUsername,
      deviceServerURLs: settings.deviceServerURLs,
      organizations: settings.organizations,
    );
  }

  @override
  Future<void> saveManagerServerURL(String? value) async {
    savedManagerServerURL = value;
    settings = AppSettings(
      managerModeEnabled: settings.managerModeEnabled,
      useBiometricLock: settings.useBiometricLock,
      darkMode: settings.darkMode,
      pushNotificationsEnabled: settings.pushNotificationsEnabled,
      managerServerURL: value,
      lastLoggedInUsername: settings.lastLoggedInUsername,
      deviceServerURLs: settings.deviceServerURLs,
      organizations: settings.organizations,
    );
  }
}

class FakeImageFeedService extends DeviceEncryptedImageFeedService {
  FakeImageFeedService({required this.onLoad, this.onDelete});

  FakeImageFeedService.noop()
    : onLoad = (({required settings, required onUpdate}) async {
        onUpdate(const <DeviceEncryptedImageFeedSection>[], true);
      }),
      onDelete = null;

  final Future<void> Function({
    required AppSettings settings,
    required void Function(List<DeviceEncryptedImageFeedSection>, bool) onUpdate,
  }) onLoad;
  final Future<void> Function(DeviceEncryptedImageFeedItem item)? onDelete;

  @override
  Future<void> loadFeedProgressively({
    required AppSettings settings,
    List<DeviceEncryptedImageFeedSection> existingSections =
        const <DeviceEncryptedImageFeedSection>[],
    required void Function(
      List<DeviceEncryptedImageFeedSection> sections,
      bool isComplete,
    ) onUpdate,
  }) {
    return onLoad(settings: settings, onUpdate: onUpdate);
  }

  @override
  Future<void> deleteImage({required DeviceEncryptedImageFeedItem item}) async {
    if (onDelete != null) {
      await onDelete!(item);
      return;
    }
    return super.deleteImage(item: item);
  }
}

final Uint8List _transparentImageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0ioAAAAASUVORK5CYII=',
);

class _AutoPopPage extends StatefulWidget {
  const _AutoPopPage({required this.result});

  final bool result;

  @override
  State<_AutoPopPage> createState() => _AutoPopPageState();
}

class _AutoPopPageState extends State<_AutoPopPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop(widget.result);
      }
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}

class _AutoPopActionPage extends StatefulWidget {
  const _AutoPopActionPage({required this.action, required this.result});

  final Future<void> Function() action;
  final bool result;

  @override
  State<_AutoPopActionPage> createState() => _AutoPopActionPageState();
}

class _AutoPopActionPageState extends State<_AutoPopActionPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.action();
      if (mounted) {
        Navigator.of(context).pop(widget.result);
      }
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}

class ThrowingImageCache extends SecureEncryptedImageBlobCache {
  @override
  Future<void> clear() async {
    throw 'cache failed';
  }
}