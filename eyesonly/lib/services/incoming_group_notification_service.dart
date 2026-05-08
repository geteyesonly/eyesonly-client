import 'dart:convert';

import 'package:eyesonly/services/crypto/eyes_only_crypto.dart';
import 'package:eyesonly/services/manager/group_content_key_store.dart';

class DecryptedGroupNotification {
  const DecryptedGroupNotification({
    required this.groupId,
    required this.body,
    this.title = 'EyesOnly',
  });

  final String groupId;
  final String title;
  final String body;
}

class IncomingGroupNotificationService {
  IncomingGroupNotificationService({GroupContentKeyStore? groupContentKeyStore})
    : _groupContentKeyStore = groupContentKeyStore ?? GroupContentKeyStore();

  final GroupContentKeyStore _groupContentKeyStore;

  Future<DecryptedGroupNotification?> decryptMessageData(
    Map<String, dynamic> data,
  ) async {
    final String groupId = _readString(data, 'group');
    final String encryptedPayload = _readString(data, 'encrypted_payload');
    final String nonce = _readString(data, 'nonce');
    if (groupId.isEmpty || encryptedPayload.isEmpty || nonce.isEmpty) {
      return null;
    }

    final List<int>? contentKeyBytes = await _groupContentKeyStore
        .readGroupContentKey(groupId, scope: groupKeyScopeGroupShared);
    if (contentKeyBytes == null) {
      return null;
    }

    try {
      final List<int> cleartext = await EyesOnlyCrypto.symmetricDecrypt(
        encryptedPayload,
        nonce,
        contentKeyBytes,
      );
      final String body = utf8.decode(cleartext).trim();
      if (body.isEmpty) {
        return null;
      }
      return DecryptedGroupNotification(
        groupId: groupId,
        body: body,
      );
    } catch (_) {
      return null;
    }
  }

  String? fallbackBody(Map<String, dynamic> data) {
    final String body = _readString(data, 'body');
    if (body.isNotEmpty) {
      return body;
    }

    final String message = _readString(data, 'message');
    if (message.isNotEmpty) {
      return message;
    }

    return null;
  }

  String _readString(Map<String, dynamic> data, String key) {
    final Object? value = data[key];
    if (value is String) {
      return value.trim();
    }
    return value?.toString().trim() ?? '';
  }
}