import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:test/test.dart';

import 'package:eyesonly/services/crypto/eyes_only_crypto.dart';
import 'package:eyesonly/services/device/api_service.dart';
import 'package:eyesonly/services/group_display_service.dart';
import 'package:eyesonly/services/manager/device_registration_keys.dart';
import 'package:eyesonly/services/manager/group_content_key_store.dart';
import 'package:eyesonly/services/manager/group_name_cipher.dart';

void main() {
  group('GroupDisplayService', () {
    test('syncs and stores a valid group key envelope', () async {
      final FakeFlutterSecureStorage secureStorage = FakeFlutterSecureStorage();
      final GroupContentKeyStore groupContentKeyStore = GroupContentKeyStore(
        secureStorage: secureStorage,
      );
      final _KeyMaterial keyMaterial = await _createKeyMaterial();
      const List<int> contentKeyBytes = <int>[
        1, 2, 3, 4, 5, 6, 7, 8,
        9, 10, 11, 12, 13, 14, 15, 16,
        17, 18, 19, 20, 21, 22, 23, 24,
        25, 26, 27, 28, 29, 30, 31, 32,
      ];
      await secureStorage.write(
        key: DeviceRegistrationKeys.privateKey,
        value: keyMaterial.privateKeyB64,
      );
      await secureStorage.write(
        key: DeviceRegistrationKeys.publicKey,
        value: keyMaterial.publicKeyB64,
      );

      final String encryptedGroupKey = await EyesOnlyCrypto.wrapForPublicKey(
        contentKeyBytes,
        keyMaterial.publicKeyB64,
        groupKeyEncryptionHkdfInfo,
      );

      final GroupDisplayService service = GroupDisplayService(
        secureStorage: secureStorage,
        groupContentKeyStore: groupContentKeyStore,
        groupKeyEnvelopeFetcher: (
          String baseUrl,
          List<String> groupIds,
          List<String>? scopes,
        ) async {
          expect(baseUrl, 'http://org');
          expect(groupIds, <String>['group-1']);
          expect(scopes, isNull);
          return <DeviceGroupKeyEnvelope>[
            DeviceGroupKeyEnvelope(
              groupId: 'group-1',
              encryptedGroupKey: encryptedGroupKey,
              scope: groupKeyScopeGroupShared,
            ),
          ];
        },
      );

      await service.syncGroupKeysFromDeviceEndpoint(
        baseUrl: 'http://org',
        groupIds: const <String>['group-1'],
      );

      expect(
        await groupContentKeyStore.readGroupContentKey('group-1'),
        contentKeyBytes,
      );
    });

    test('does not fetch envelopes when the device keypair is missing', () async {
      bool fetchCalled = false;
      final GroupDisplayService service = GroupDisplayService(
        secureStorage: FakeFlutterSecureStorage(),
        groupKeyEnvelopeFetcher: (
          String baseUrl,
          List<String> groupIds,
          List<String>? scopes,
        ) async {
          fetchCalled = true;
          return const <DeviceGroupKeyEnvelope>[];
        },
      );

      await service.syncGroupKeysFromDeviceEndpoint(
        baseUrl: 'http://org',
        groupIds: const <String>['group-1'],
      );

      expect(fetchCalled, isFalse);
    });

    test('skips envelopes that cannot be unwrapped', () async {
      final FakeFlutterSecureStorage secureStorage = FakeFlutterSecureStorage();
      final GroupContentKeyStore groupContentKeyStore = GroupContentKeyStore(
        secureStorage: secureStorage,
      );
      final _KeyMaterial keyMaterial = await _createKeyMaterial();
      await secureStorage.write(
        key: DeviceRegistrationKeys.privateKey,
        value: keyMaterial.privateKeyB64,
      );
      await secureStorage.write(
        key: DeviceRegistrationKeys.publicKey,
        value: keyMaterial.publicKeyB64,
      );

      final GroupDisplayService service = GroupDisplayService(
        secureStorage: secureStorage,
        groupContentKeyStore: groupContentKeyStore,
        groupKeyEnvelopeFetcher: (_, _, _) async => const <DeviceGroupKeyEnvelope>[
          DeviceGroupKeyEnvelope(
            groupId: 'group-1',
            encryptedGroupKey: 'not-an-envelope',
          ),
        ],
      );

      await service.syncGroupKeysFromDeviceEndpoint(
        baseUrl: 'http://org',
        groupIds: const <String>['group-1'],
      );

      expect(await groupContentKeyStore.readGroupContentKey('group-1'), isNull);
    });

    test('decrypts group names when a stored content key is available', () async {
      final FakeFlutterSecureStorage secureStorage = FakeFlutterSecureStorage();
      final GroupContentKeyStore groupContentKeyStore = GroupContentKeyStore(
        secureStorage: secureStorage,
      );
      const List<int> contentKeyBytes = <int>[
        32, 31, 30, 29, 28, 27, 26, 25,
        24, 23, 22, 21, 20, 19, 18, 17,
        16, 15, 14, 13, 12, 11, 10, 9,
        8, 7, 6, 5, 4, 3, 2, 1,
      ];
      final ({String ciphertext, String nonce}) encryptedName =
          await EyesOnlyCrypto.symmetricEncrypt(
        utf8.encode('Alpha'),
        contentKeyBytes,
      );
      await groupContentKeyStore.saveGroupContentKey('group-1', contentKeyBytes);

      final GroupDisplayService service = GroupDisplayService(
        secureStorage: secureStorage,
        groupContentKeyStore: groupContentKeyStore,
      );

      expect(
        await service.tryDecryptGroupName(
          groupId: 'group-1',
          encryptedName: encryptedName.ciphertext,
          nameNonce: encryptedName.nonce,
        ),
        'Alpha',
      );
    });

    test('returns null when group name decryption cannot succeed', () async {
      final GroupDisplayService service = GroupDisplayService(
        secureStorage: FakeFlutterSecureStorage(),
        groupContentKeyStore: GroupContentKeyStore(
          secureStorage: FakeFlutterSecureStorage(),
        ),
      );

      expect(
        await service.tryDecryptGroupName(
          groupId: 'group-1',
          encryptedName: 'bad-ciphertext',
          nameNonce: 'bad-nonce',
        ),
        isNull,
      );
      expect(
        await service.tryDecryptGroupName(
          groupId: '',
          encryptedName: 'x',
          nameNonce: 'y',
        ),
        isNull,
      );
    });
  });
}

Future<_KeyMaterial> _createKeyMaterial() async {
  final KeyPair keyPair = await X25519().newKeyPair();
  final SimpleKeyPairData keyPairData =
      await keyPair.extract() as SimpleKeyPairData;
  return _KeyMaterial(
    privateKeyB64: base64Encode(keyPairData.bytes),
    publicKeyB64: base64Encode(keyPairData.publicKey.bytes),
  );
}

class _KeyMaterial {
  const _KeyMaterial({
    required this.privateKeyB64,
    required this.publicKeyB64,
  });

  final String privateKeyB64;
  final String publicKeyB64;
}

class FakeFlutterSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    MacOsOptions? mOptions,
  }) async {
    _values.remove(key);
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    MacOsOptions? mOptions,
  }) async {
    return _values[key];
  }

  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    MacOsOptions? mOptions,
  }) async {
    return Map<String, String>.from(_values);
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    MacOsOptions? mOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
      return;
    }
    _values[key] = value;
  }
}