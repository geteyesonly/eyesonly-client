import 'dart:convert';

import 'package:test/test.dart';

import 'package:eyesonly/services/crypto/eyes_only_crypto.dart';
import 'package:eyesonly/services/incoming_group_notification_service.dart';
import 'package:eyesonly/services/manager/group_content_key_store.dart';

void main() {
  test('decrypts an incoming encrypted group notification payload', () async {
    final List<int> keyBytes = List<int>.generate(32, (int index) => index + 1);
    final ({String ciphertext, String nonce}) encrypted =
        await EyesOnlyCrypto.symmetricEncrypt(
          utf8.encode('There are new images for you'),
          keyBytes,
        );
    final IncomingGroupNotificationService service =
        IncomingGroupNotificationService(
          groupContentKeyStore: FakeGroupContentKeyStore(
            <String, List<int>>{
              'group_shared::group-1': keyBytes,
            },
          ),
        );

    final DecryptedGroupNotification? notification =
        await service.decryptMessageData(<String, dynamic>{
          'group': 'group-1',
          'encrypted_payload': encrypted.ciphertext,
          'nonce': encrypted.nonce,
        });

    expect(notification, isNotNull);
    expect(notification!.groupId, 'group-1');
    expect(notification.body, 'There are new images for you');
  });

  test('returns null when the shared group key is unavailable', () async {
    final IncomingGroupNotificationService service =
        IncomingGroupNotificationService(
          groupContentKeyStore: FakeGroupContentKeyStore(
            const <String, List<int>>{},
          ),
        );

    final DecryptedGroupNotification? notification =
        await service.decryptMessageData(<String, dynamic>{
          'group': 'group-1',
          'encrypted_payload': 'ciphertext',
          'nonce': 'nonce',
        });

    expect(notification, isNull);
  });
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