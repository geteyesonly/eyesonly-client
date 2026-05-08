import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:test/test.dart';

void main() {
  test('xchacha20-poly1305 roundtrip succeeds', () async {
    final Xchacha20 algorithm = Xchacha20.poly1305Aead();
    final SecretKey secretKey = await algorithm.newSecretKey();
    final List<int> nonce = algorithm.newNonce();
    final List<int> message = utf8.encode(
      'Dart XChaCha20-Poly1305 test message!',
    );

    final SecretBox secretBox = await algorithm.encrypt(
      message,
      secretKey: secretKey,
      nonce: nonce,
    );

    final List<int> cleartext = await algorithm.decrypt(
      SecretBox(
        secretBox.cipherText,
        nonce: secretBox.nonce,
        mac: secretBox.mac,
      ),
      secretKey: secretKey,
    );

    expect(utf8.decode(cleartext), 'Dart XChaCha20-Poly1305 test message!');
    expect(base64Encode(secretBox.nonce), isNotEmpty);
    expect(base64Encode(secretBox.mac.bytes), isNotEmpty);
  });
}
