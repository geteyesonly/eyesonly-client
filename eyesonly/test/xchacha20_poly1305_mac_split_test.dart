import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:test/test.dart';

void main() {
  test('ciphertext+mac split decrypts successfully', () async {
    final Xchacha20 algorithm = Xchacha20.poly1305Aead();
    final SecretKey hkdfKey = await algorithm.newSecretKey();
    final List<int> nonce = algorithm.newNonce();
    final List<int> message = utf8.encode('ciphertext mac split test');
    final SecretBox originalSecretBox = await algorithm.encrypt(
      message,
      secretKey: hkdfKey,
      nonce: nonce,
    );
    final List<int> ciphertext = <int>[
      ...originalSecretBox.cipherText,
      ...originalSecretBox.mac.bytes,
    ];
    const int macLength = 16;
    final SecretBox secretBox = SecretBox(
      ciphertext.sublist(0, ciphertext.length - macLength),
      nonce: nonce,
      mac: Mac(ciphertext.sublist(ciphertext.length - macLength)),
    );

    final List<int> cleartext = await algorithm.decrypt(
      secretBox,
      secretKey: hkdfKey,
    );

    expect(utf8.decode(cleartext), 'ciphertext mac split test');
  });
}
