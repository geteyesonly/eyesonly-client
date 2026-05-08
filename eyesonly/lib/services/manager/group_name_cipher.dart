import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api_exception.dart';
import '../crypto/eyes_only_crypto.dart';
import 'device_registration_keys.dart';

const String groupKeyEncryptionHkdfInfo = 'eyesonly-group-key-encryption-v1';

class GroupNameCipher {
  GroupNameCipher({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  /// Generates a fresh random 32-byte symmetric content key.
  Future<List<int>> generateContentKeyBytes() async {
    return EyesOnlyCrypto.generateKey();
  }

  Future<({String encryptedName, String nameNonce})> encryptGroupName(
    String groupName,
    List<int> contentKeyBytes,
  ) async {
    final ({String ciphertext, String nonce}) result =
        await EyesOnlyCrypto.symmetricEncrypt(
      utf8.encode(groupName),
      contentKeyBytes,
    );
    return (encryptedName: result.ciphertext, nameNonce: result.nonce);
  }

  Future<({String encryptedGroupKey, String fingerprint})>
      wrapKeyForManagerDevice(List<int> contentKeyBytes) async {
    final String? publicKeyB64 =
        await _secureStorage.read(key: DeviceRegistrationKeys.publicKey);
    if (publicKeyB64 == null || publicKeyB64.isEmpty) {
      throw ApiException('Manager device public key not available.');
    }

    final String fingerprint =
        await EyesOnlyCrypto.publicKeyFingerprint(publicKeyB64);
    final String encryptedGroupKey = await EyesOnlyCrypto.wrapForPublicKey(
      contentKeyBytes,
      publicKeyB64,
      groupKeyEncryptionHkdfInfo,
    );

    return (encryptedGroupKey: encryptedGroupKey, fingerprint: fingerprint);
  }
}
