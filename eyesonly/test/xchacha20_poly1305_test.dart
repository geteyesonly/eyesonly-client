import 'package:cryptography/cryptography.dart';
import 'package:test/test.dart';

void main() {
  test('missing MAC fails decryption', () async {
    final SecretKey hkdfKey = SecretKey(<int>[
      16, 180, 118, 55, 95, 169, 234, 89, 64, 238, 111, 121, 74, 133, 80,
      192, 35, 168, 187, 8, 252, 69, 234, 95, 207, 158, 212, 35, 218, 183,
      119, 193,
    ]);
    final SecretBox secretBox = SecretBox(
      <int>[
        97, 42, 122, 173, 155, 76, 134, 172, 59, 181, 247, 107, 167, 223,
        110, 142, 95, 241, 209, 255, 139, 60, 4, 3, 140, 87, 199, 9, 228,
        162, 149, 247, 215, 101, 115, 226, 72, 105, 88, 171, 83, 192, 158,
        173, 106, 215, 47, 98, 102, 170, 229, 155, 53, 31, 191, 50, 201,
        217, 189,
      ],
      nonce: <int>[
        217, 160, 196, 123, 212, 39, 139, 122, 147, 146, 57, 128, 117, 133,
        183, 38, 192, 189, 33, 13, 233, 196, 160, 182,
      ],
      mac: Mac.empty,
    );

    await expectLater(
      () => Xchacha20.poly1305Aead().decrypt(secretBox, secretKey: hkdfKey),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
}
