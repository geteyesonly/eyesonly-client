import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api_exception.dart';
import '../crypto/eyes_only_crypto.dart';
import 'device_registration_keys.dart';

const String ownerNameEncryptionHkdfInfo =
    'eyesonly-owner-name-encryption-v1';

class OwnerNameCipher {
  OwnerNameCipher({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _privateKeyKey = DeviceRegistrationKeys.privateKey;
  static const String _publicKeyKey = DeviceRegistrationKeys.publicKey;

  final FlutterSecureStorage _secureStorage;

  Future<String> encryptForPublicKey({
    required String ownerName,
    required String recipientPublicKey,
  }) async {
    return EyesOnlyCrypto.wrapForPublicKey(
      utf8.encode(ownerName),
      recipientPublicKey,
      ownerNameEncryptionHkdfInfo,
    );
  }

  Future<String> decryptForCurrentDevice(String encryptedOwnerName) async {
    final String trimmed = encryptedOwnerName.trim();
    if (trimmed.isEmpty) {
      throw ApiException('Owner name payload is empty.');
    }

    try {
      final String? privateKeyB64 = await _secureStorage.read(key: _privateKeyKey);
      final String? publicKeyB64 = await _secureStorage.read(key: _publicKeyKey);
      if (privateKeyB64 == null || privateKeyB64.isEmpty) {
        throw ApiException('Manager device private key not available.');
      }
      if (publicKeyB64 == null || publicKeyB64.isEmpty) {
        throw ApiException('Manager device public key not available.');
      }

      final List<int> cleartext = await EyesOnlyCrypto.unwrapWithPrivateKey(
        trimmed,
        base64Decode(privateKeyB64),
        base64Decode(publicKeyB64),
        ownerNameEncryptionHkdfInfo,
      );
      return utf8.decode(cleartext).trim();
    } catch (_) {
      try {
        final String legacyDecoded = utf8.decode(base64Decode(trimmed)).trim();
        if (legacyDecoded.isNotEmpty && !_looksLikeStructuredPayload(legacyDecoded)) {
          return legacyDecoded;
        }
      } catch (_) {
        // Ignore legacy fallback failure.
      }
      throw ApiException('Owner name could not be decrypted on this device.');
    }
  }

  bool _looksLikeStructuredPayload(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return true;
    }

    try {
      final dynamic decoded = jsonDecode(trimmed);
      return decoded is Map || decoded is List;
    } catch (_) {
      return false;
    }
  }
}