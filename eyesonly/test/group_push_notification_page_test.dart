import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eyesonly/screens/group_detail_page.dart';
import 'package:eyesonly/services/group_display_service.dart';
import 'package:eyesonly/services/manager/api_service.dart';
import 'package:eyesonly/services/manager/group_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('manager can send the default group notification message', (
    WidgetTester tester,
  ) async {
    final FakeManagerApiService managerApiService = FakeManagerApiService();
    final FakeGroupNotificationService notificationService =
        FakeGroupNotificationService();

    await tester.pumpWidget(
      MaterialApp(
        home: GroupDetailPage(
          groupId: 'group-1',
          groupName: 'Alpha',
          baseUrl: 'http://org',
          organizationName: 'Org',
          isManager: true,
          managerApiService: managerApiService,
          groupDisplayService: FakeGroupDisplayService(),
          groupNotificationService: notificationService,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Send Message to Group'));
    await tester.pumpAndSettle();

    expect(find.text('Send Message to Group'), findsOneWidget);
    expect(
      find.text(GroupNotificationService.fixedNotificationMessage),
      findsOneWidget,
    );

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(notificationService.lastGroupId, 'group-1');
    expect(notificationService.lastBaseUrl, 'http://org');
    expect(find.text('Notification sent to 3 devices.'), findsOneWidget);
  });
}

class FakeGroupDisplayService extends GroupDisplayService {
  @override
  Future<void> syncGroupKeysFromDeviceEndpoint({
    required String baseUrl,
    required Iterable<String> groupIds,
    List<String>? scopes,
  }) async {}
}

class FakeManagerApiService extends ManagerApiService {
  FakeManagerApiService() : super(baseUrl: 'http://example.test');

  @override
  Future<void> hydrateTokens() async {}

  @override
  Future<List<MainManagerGroupDevice>> getMainManagerGroupDevices({
    required String groupId,
  }) async {
    return const <MainManagerGroupDevice>[];
  }
}

class FakeGroupNotificationService extends GroupNotificationService {
  FakeGroupNotificationService();

  String? lastBaseUrl;
  String? lastGroupId;

  @override
  Future<GroupNotificationResult> sendGroupNotification({
    required String baseUrl,
    required String groupId,
  }) async {
    lastBaseUrl = baseUrl;
    lastGroupId = groupId;
    return const GroupNotificationResult(notifiedCount: 3, skippedCount: 0);
  }
}