import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:eyesonly/services/crypto/eyes_only_crypto.dart';
import 'package:eyesonly/services/group_display_service.dart';
import 'package:eyesonly/services/manager/api_service.dart';
import 'package:eyesonly/services/manager/group_content_key_store.dart';
import 'package:eyesonly/services/manager/group_notification_service.dart';

void main() {
  test('encrypts the group notification payload with the shared group key', () async {
    final FakeGroupContentKeyStore keyStore = FakeGroupContentKeyStore(
      <String, List<int>>{
        'group_shared::group-1': List<int>.generate(32, (int index) => index),
      },
    );
    final FakeGroupDisplayService groupDisplayService = FakeGroupDisplayService();
    final FakeManagerApiService managerApiService = FakeManagerApiService();
    final GroupNotificationService service = GroupNotificationService(
      managerApiService: managerApiService,
      groupDisplayService: groupDisplayService,
      groupContentKeyStore: keyStore,
    );

    final GroupNotificationResult result = await service.sendGroupNotification(
      baseUrl: 'http://org',
      groupId: 'group-1',
    );

    expect(groupDisplayService.syncedBaseUrl, 'http://org');
    expect(groupDisplayService.syncedGroupIds, <String>['group-1']);
    expect(managerApiService.lastGroupId, 'group-1');
    expect(managerApiService.lastEncryptionAlgorithm, EyesOnlyCrypto.symmetricAlgorithm);
    expect(result.notifiedCount, 2);
    expect(result.skippedCount, 1);

    final List<int> decryptedBytes = await EyesOnlyCrypto.symmetricDecrypt(
      managerApiService.lastEncryptedPayload!,
      managerApiService.lastNonce!,
      List<int>.generate(32, (int index) => index),
    );
    expect(utf8.decode(decryptedBytes), 'There are new images for you');
  });
}

class FakeGroupDisplayService extends GroupDisplayService {
  String? syncedBaseUrl;
  List<String> syncedGroupIds = <String>[];

  @override
  Future<void> syncGroupKeysFromDeviceEndpoint({
    required String baseUrl,
    required Iterable<String> groupIds,
    List<String>? scopes,
  }) async {
    syncedBaseUrl = baseUrl;
    syncedGroupIds = groupIds.toList();
  }
}

class FakeGroupContentKeyStore extends GroupContentKeyStore {
  FakeGroupContentKeyStore(this.values);

  final Map<String, List<int>> values;

  @override
  Future<List<int>?> readGroupContentKey(
    String groupId, {
    String scope = groupKeyScopeGroupShared,
  }) async {
    return values['$scope::$groupId'];
  }
}

class FakeManagerApiService extends ManagerApiService {
  FakeManagerApiService() : super(baseUrl: 'http://example.test');

  String? lastGroupId;
  String? lastEncryptedPayload;
  String? lastNonce;
  String? lastEncryptionAlgorithm;

  @override
  Future<void> hydrateTokens() async {}

  @override
  Future<Map<String, dynamic>> notifyGroup({
    required String groupId,
    required String encryptedPayload,
    required String nonce,
    int cryptoVersion = 1,
    String encryptionAlgorithm = 'xchacha20poly1305',
    String endpoint = '',
  }) async {
    lastGroupId = groupId;
    lastEncryptedPayload = encryptedPayload;
    lastNonce = nonce;
    lastEncryptionAlgorithm = encryptionAlgorithm;
    return <String, dynamic>{'notified_count': 2, 'skipped_count': 1};
  }
}