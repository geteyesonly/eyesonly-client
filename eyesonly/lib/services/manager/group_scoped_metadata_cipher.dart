import 'dart:convert';

import '../api_exception.dart';
import '../crypto/eyes_only_crypto.dart';
import 'group_content_key_store.dart';

class GroupScopedMetadataCipher {
  GroupScopedMetadataCipher({GroupContentKeyStore? groupContentKeyStore})
    : _groupContentKeyStore = groupContentKeyStore ?? GroupContentKeyStore();

  final GroupContentKeyStore _groupContentKeyStore;

  Future<String> encryptForGroup({
    required String groupId,
    required String scope,
    required String plaintext,
  }) async {
    final String normalizedGroupId = groupId.trim();
    final String normalizedPlaintext = plaintext.trim();
    if (normalizedGroupId.isEmpty || normalizedPlaintext.isEmpty) {
      throw ApiException('Missing scoped group metadata to encrypt.');
    }

    final List<int>? keyBytes = await _groupContentKeyStore.readGroupContentKey(
      normalizedGroupId,
      scope: scope,
    );
    if (keyBytes == null) {
      throw ApiException('Required scoped group key is not available on this device.');
    }

    final ({String ciphertext, String nonce}) encrypted =
        await EyesOnlyCrypto.symmetricEncrypt(
      utf8.encode(normalizedPlaintext),
      keyBytes,
    );

    return base64Encode(
      utf8.encode(
        jsonEncode(<String, String>{
          'algorithm': EyesOnlyCrypto.symmetricAlgorithm,
          'nonce': encrypted.nonce,
          'ciphertext': encrypted.ciphertext,
        }),
      ),
    );
  }

  Future<String> decryptForGroup({
    required String groupId,
    required String scope,
    required String encryptedPayload,
  }) async {
    final String normalizedGroupId = groupId.trim();
    final String normalizedPayload = encryptedPayload.trim();
    if (normalizedGroupId.isEmpty || normalizedPayload.isEmpty) {
      throw ApiException('Missing scoped group metadata to decrypt.');
    }

    final List<int>? keyBytes = await _groupContentKeyStore.readGroupContentKey(
      normalizedGroupId,
      scope: scope,
    );
    if (keyBytes == null) {
      throw ApiException('Required scoped group key is not available on this device.');
    }

    final dynamic decoded = jsonDecode(utf8.decode(base64Decode(normalizedPayload)));
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Scoped group metadata payload is malformed.');
    }

    final String nonce = (decoded['nonce'] as String?)?.trim() ?? '';
    final String ciphertext = (decoded['ciphertext'] as String?)?.trim() ?? '';
    if (nonce.isEmpty || ciphertext.isEmpty) {
      throw ApiException('Scoped group metadata payload is incomplete.');
    }

    final List<int> cleartext = await EyesOnlyCrypto.symmetricDecrypt(
      ciphertext,
      nonce,
      keyBytes,
    );
    return utf8.decode(cleartext).trim();
  }
}