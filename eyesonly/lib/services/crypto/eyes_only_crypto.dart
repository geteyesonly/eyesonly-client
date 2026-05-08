import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../api_exception.dart';
import '../device/allowed_algorithms.dart';

/// Low-level cryptographic primitives used throughout EyesOnly.
///
/// All symmetric encryption uses XChaCha20-Poly1305.
/// All asymmetric key exchange uses X25519 + HKDF-SHA256 + XChaCha20-Poly1305.
///
/// Higher-level cipher classes ([OwnerNameCipher], [GroupNameCipher], etc.)
/// delegate to this class so that algorithm choices are centralised here.
class EyesOnlyCrypto {
  EyesOnlyCrypto._();

  // ─── Algorithm identifier constants ────────────────────────────────────────

  /// Full asymmetric-wrap algorithm identifier, as stored in envelope JSON and
  /// sent to the server.
  static const String asymmetricAlgorithm = defaultDeviceChallengeAlgorithm;

  /// Symmetric-only algorithm identifier.
  static const String symmetricAlgorithm = 'xchacha20poly1305';

  // ─── Key generation ────────────────────────────────────────────────────────

  /// Generates a fresh random 32-byte symmetric key for XChaCha20-Poly1305.
  static Future<List<int>> generateKey() async {
    final SecretKey key = await Xchacha20.poly1305Aead().newSecretKey();
    return key.extractBytes();
  }

  // ─── Symmetric encrypt / decrypt ───────────────────────────────────────────

  /// Encrypts [plainBytes] with [keyBytes] using XChaCha20-Poly1305.
  ///
  /// Returns `(ciphertext, nonce)`, both base64-encoded. The ciphertext
  /// already includes the 16-byte Poly1305 MAC appended.
  static Future<({String ciphertext, String nonce})> symmetricEncrypt(
    List<int> plainBytes,
    List<int> keyBytes,
  ) async {
    final SecretKey key = SecretKey(keyBytes);
    final SecretBox secretBox = await Xchacha20.poly1305Aead().encrypt(
      plainBytes,
      secretKey: key,
    );
    return (
      ciphertext: base64Encode(<int>[
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ]),
      nonce: base64Encode(secretBox.nonce),
    );
  }

  /// Decrypts a value produced by [symmetricEncrypt].
  ///
  /// [ciphertextB64]: base64(ciphertext + mac)
  /// [nonceB64]: base64(nonce)
  static Future<List<int>> symmetricDecrypt(
    String ciphertextB64,
    String nonceB64,
    List<int> keyBytes,
  ) async {
    final List<int> ciphertextWithMac = base64Decode(ciphertextB64);
    const int macLength = 16;
    final SecretBox secretBox = SecretBox(
      ciphertextWithMac.sublist(0, ciphertextWithMac.length - macLength),
      nonce: base64Decode(nonceB64),
      mac: Mac(ciphertextWithMac.sublist(ciphertextWithMac.length - macLength)),
    );
    return Xchacha20.poly1305Aead().decrypt(
      secretBox,
      secretKey: SecretKey(keyBytes),
    );
  }

  // ─── Asymmetric wrap / unwrap ───────────────────────────────────────────────

  /// Wraps [plainBytes] for [recipientPublicKeyB64] using
  /// X25519 ECDH → HKDF-SHA256 (with [hkdfInfo]) → XChaCha20-Poly1305.
  ///
  /// [hkdfInfo] provides domain separation between different wrapping contexts
  /// (e.g. owner-name vs group-key). Each context must use a unique string.
  ///
  /// Returns a base64-encoded JSON envelope:
  /// `{algorithm, ephemeral_public_key, nonce, ciphertext}`.
  static Future<String> wrapForPublicKey(
    List<int> plainBytes,
    String recipientPublicKeyB64,
    String hkdfInfo,
  ) async {
    final SimplePublicKey recipientPublicKey = SimplePublicKey(
      base64Decode(recipientPublicKeyB64),
      type: KeyPairType.x25519,
    );

    final X25519 x25519 = X25519();
    final KeyPair ephemeralKeyPair = await x25519.newKeyPair();
    final PublicKey ephemeralPublicKeyRaw =
        await ephemeralKeyPair.extractPublicKey();
    if (ephemeralPublicKeyRaw is! SimplePublicKey) {
      throw ApiException('Unsupported ephemeral public key type.');
    }

    final SecretKey sharedSecret = await x25519.sharedSecretKey(
      keyPair: ephemeralKeyPair,
      remotePublicKey: recipientPublicKey,
    );
    final SecretKey symmetricKey = await Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    ).deriveKey(
      secretKey: sharedSecret,
      info: utf8.encode(hkdfInfo),
    );

    final SecretBox secretBox = await Xchacha20.poly1305Aead().encrypt(
      plainBytes,
      secretKey: symmetricKey,
    );

    final Map<String, dynamic> envelope = <String, dynamic>{
      'algorithm': asymmetricAlgorithm,
      'ephemeral_public_key': base64Encode(ephemeralPublicKeyRaw.bytes),
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(<int>[
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ]),
    };

    return base64Encode(utf8.encode(jsonEncode(envelope)));
  }

  /// Unwraps an envelope produced by [wrapForPublicKey].
  ///
  /// [envelopeB64]: the base64-encoded JSON envelope string.
  /// [privateKeyBytes] / [publicKeyBytes]: the recipient's X25519 key pair.
  /// [hkdfInfo]: must match the value used during [wrapForPublicKey].
  ///
  /// Throws [ApiException] on any failure.
  static Future<List<int>> unwrapWithPrivateKey(
    String envelopeB64,
    List<int> privateKeyBytes,
    List<int> publicKeyBytes,
    String hkdfInfo,
  ) async {
    final Map<String, dynamic> envelope = _decodeEnvelope(envelopeB64);
    final String algorithm = (envelope['algorithm'] as String?)?.trim() ?? '';
    if (!allowedDeviceChallengeAlgorithms.contains(algorithm.toLowerCase())) {
      throw ApiException('Unsupported envelope algorithm: $algorithm');
    }

    final SimpleKeyPairData deviceKeyPair = SimpleKeyPairData(
      privateKeyBytes,
      publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );
    final SimplePublicKey ephemeralPublicKey = SimplePublicKey(
      base64Decode((envelope['ephemeral_public_key'] as String?) ?? ''),
      type: KeyPairType.x25519,
    );

    final SecretKey sharedSecret = await X25519().sharedSecretKey(
      keyPair: deviceKeyPair,
      remotePublicKey: ephemeralPublicKey,
    );
    final SecretKey symmetricKey = await Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    ).deriveKey(
      secretKey: sharedSecret,
      info: utf8.encode(hkdfInfo),
    );

    final List<int> ciphertextWithMac =
        base64Decode((envelope['ciphertext'] as String?) ?? '');
    const int macLength = 16;
    final SecretBox secretBox = SecretBox(
      ciphertextWithMac.sublist(0, ciphertextWithMac.length - macLength),
      nonce: base64Decode((envelope['nonce'] as String?) ?? ''),
      mac: Mac(ciphertextWithMac.sublist(ciphertextWithMac.length - macLength)),
    );

    return Xchacha20.poly1305Aead().decrypt(secretBox, secretKey: symmetricKey);
  }

  // ─── Key fingerprint ───────────────────────────────────────────────────────

  /// Returns the hex-encoded SHA-256 fingerprint of a base64-encoded public key.
  static Future<String> publicKeyFingerprint(String publicKeyB64) async {
    final Hash hash = await Sha256().hash(base64Decode(publicKeyB64));
    return hash.bytes
        .map((int b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  // ─── Internal helpers ──────────────────────────────────────────────────────

  static Map<String, dynamic> _decodeEnvelope(String envelopeB64) {
    try {
      final dynamic decoded =
          jsonDecode(utf8.decode(base64Decode(envelopeB64)));
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    throw ApiException('Envelope has an invalid format.');
  }
}
