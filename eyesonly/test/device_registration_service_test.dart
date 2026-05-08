import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:test/test.dart';

import 'package:eyesonly/services/api_exception.dart';
import 'package:eyesonly/services/crypto/eyes_only_crypto.dart';
import 'package:eyesonly/services/device/api_service.dart' as device;
import 'package:eyesonly/services/installation_id_store.dart';
import 'package:eyesonly/services/manager/api_service.dart';
import 'package:eyesonly/services/manager/device_registration_service.dart';
import 'package:eyesonly/services/manager/group_content_key_store.dart';
import 'package:eyesonly/services/manager/group_name_cipher.dart';

void main() {
  group('DeviceRegistrationService', () {
    test('ensureRegistered marks the device registered when the server already knows it', () async {
      final FakeFlutterSecureStorage secureStorage = FakeFlutterSecureStorage();
      final DeviceRegistrationService service = DeviceRegistrationService(
        secureStorage: secureStorage,
        installationIdStore: FixedInstallationIdStore('device-123'),
        deviceSelfStatusFetcher: (_) async => const device.DeviceSelfStatus(
          deviceIdentifier: 'device-123',
          isRegistered: true,
        ),
      );
      final FakeManagerApiService managerApiService = FakeManagerApiService(
        baseUrl: 'http://manager',
      );

      await service.ensureRegistered(
        managerApiService: managerApiService,
        username: 'tom',
      );

      expect(managerApiService.registerDeviceCalls, isEmpty);
      expect(
        await secureStorage.read(key: 'device_registered'),
        'true',
      );
    });

    test('ensureRegistered registers the device and extracts owner user id from JWT', () async {
      final FakeFlutterSecureStorage secureStorage = FakeFlutterSecureStorage();
      final FakeManagerApiService managerApiService = FakeManagerApiService(
        baseUrl: 'http://manager',
        accessTokenValue: _jwtWithUserId(42),
      );
      final DeviceRegistrationService service = DeviceRegistrationService(
        secureStorage: secureStorage,
        installationIdStore: FixedInstallationIdStore('device-123'),
        deviceSelfStatusFetcher: (_) async {
          throw ApiException('offline');
        },
      );

      await service.ensureRegistered(
        managerApiService: managerApiService,
        username: 'tom',
      );

      expect(managerApiService.registerDeviceCalls, hasLength(1));
      final RegisterDeviceCall call = managerApiService.registerDeviceCalls.single;
      expect(call.deviceIdentifier, 'device-123');
      expect(call.publicKey, isNotEmpty);
      expect(call.publicKeyAlgorithm, 'x25519');
      expect(call.ownerUser, 42);
      expect(await secureStorage.read(key: 'device_private_key'), isNotNull);
      expect(await secureStorage.read(key: 'device_public_key'), isNotNull);
      expect(await secureStorage.read(key: 'device_registered'), 'true');
      expect(await secureStorage.read(key: 'device_registered_owner_name'), 'tom');
    });

    test('createRegistrationDataForDevice generates key material for a new managed device', () async {
      final DeviceRegistrationService service = DeviceRegistrationService(
        secureStorage: FakeFlutterSecureStorage(),
        installationIdStore: FixedInstallationIdStore('manager-device'),
      );

      final DeviceRegistrationData registrationData =
          await service.createRegistrationDataForDevice(
        deviceIdentifier: 'member-1',
        ownerName: 'Alice',
      );

      expect(registrationData.deviceIdentifier, 'member-1');
      expect(registrationData.memberName, 'Alice');
      expect(registrationData.publicKey, isNotEmpty);
      expect(registrationData.publicKeyAlgorithm, 'x25519');
    });

    test('getOrCreateJoinRequestData reuses the same key material across calls', () async {
      final DeviceRegistrationService service = DeviceRegistrationService(
        secureStorage: FakeFlutterSecureStorage(),
        installationIdStore: FixedInstallationIdStore('device-123'),
      );

      final DeviceJoinRequestData first = await service.getOrCreateJoinRequestData();
      final DeviceJoinRequestData second = await service.getOrCreateJoinRequestData();

      expect(first.deviceIdentifier, 'device-123');
      expect(second.deviceIdentifier, 'device-123');
      expect(first.publicKeyAlgorithm, 'x25519');
      expect(second.publicKeyAlgorithm, 'x25519');
      expect(second.publicKey, first.publicKey);
    });

    test('ensureCurrentDeviceAddedToMainManagerGroups only adds missing groups', () async {
      final FakeGroupContentKeyStore groupContentKeyStore = FakeGroupContentKeyStore();
      await groupContentKeyStore.saveGroupContentKey(
        'group-2',
        List<int>.generate(32, (int index) => index + 1),
        scope: groupKeyScopeManagerRoster,
      );
      final FakeManagerApiService managerApiService = FakeManagerApiService(
        baseUrl: 'http://manager',
        mainManagerGroups: <Map<String, dynamic>>[
          <String, dynamic>{'uuid': 'group-1'},
          <String, dynamic>{'uuid': 'group-2'},
          <String, dynamic>{'uuid': ''},
        ],
        groupDevicesById: <String, List<MainManagerGroupDevice>>{
          'group-1': <MainManagerGroupDevice>[
            const MainManagerGroupDevice(
              deviceIdentifier: 'device-123',
              encryptedMemberName: 'enc',
              publicKey: 'key',
              publicKeyFingerprint: 'fingerprint',
            ),
          ],
          'group-2': <MainManagerGroupDevice>[
            const MainManagerGroupDevice(
              deviceIdentifier: 'other-device',
              encryptedMemberName: 'enc',
              publicKey: 'key',
              publicKeyFingerprint: 'fingerprint',
            ),
          ],
        },
      );
      final DeviceRegistrationService service = DeviceRegistrationService(
        secureStorage: FakeFlutterSecureStorage(),
        installationIdStore: FixedInstallationIdStore('device-123'),
        groupContentKeyStore: groupContentKeyStore,
      );

      await service.ensureCurrentDeviceAddedToMainManagerGroups(
        managerApiService: managerApiService,
        username: 'tom',
      );

      expect(managerApiService.addDeviceCalls.map((AddDeviceCall call) => call.groupId), <String>['group-2']);
    });

    test('ensureCurrentDeviceAddedToMainManagerGroups provisions envelopes when a local group key is available', () async {
      final FakeGroupContentKeyStore groupContentKeyStore = FakeGroupContentKeyStore();
      const List<int> contentKeyBytes = <int>[
        5, 4, 3, 2, 1, 0, 9, 8,
        7, 6, 5, 4, 3, 2, 1, 0,
        1, 3, 5, 7, 9, 11, 13, 15,
        2, 4, 6, 8, 10, 12, 14, 16,
      ];
      await groupContentKeyStore.saveGroupContentKey('group-1', contentKeyBytes);
      final _KeyMaterial currentKeyMaterial = await _createKeyMaterial();
      final _KeyMaterial peerKeyMaterial = await _createKeyMaterial();
      final FakeManagerApiService managerApiService = FakeManagerApiService(
        baseUrl: 'http://manager',
        mainManagerGroups: <Map<String, dynamic>>[
          <String, dynamic>{'uuid': 'group-1'},
        ],
        groupDevicesById: <String, List<MainManagerGroupDevice>>{
          'group-1': <MainManagerGroupDevice>[
            MainManagerGroupDevice(
              deviceIdentifier: 'device-123',
              encryptedMemberName: 'enc-current',
              publicKey: currentKeyMaterial.publicKeyB64,
              publicKeyFingerprint: '',
            ),
            MainManagerGroupDevice(
              deviceIdentifier: 'device-456',
              encryptedMemberName: 'enc-peer',
              publicKey: peerKeyMaterial.publicKeyB64,
              publicKeyFingerprint: '',
            ),
          ],
        },
      );
      final DeviceRegistrationService service = DeviceRegistrationService(
        secureStorage: FakeFlutterSecureStorage(),
        installationIdStore: FixedInstallationIdStore('device-123'),
        groupContentKeyStore: groupContentKeyStore,
      );

      await service.ensureCurrentDeviceAddedToMainManagerGroups(
        managerApiService: managerApiService,
        username: 'tom',
      );

      expect(managerApiService.addDeviceCalls, isEmpty);
      expect(managerApiService.envelopeCalls, hasLength(1));

      final CreateEnvelopeCall envelopeCall = managerApiService.envelopeCalls.single;
      expect(envelopeCall.groupId, 'group-1');
      expect(envelopeCall.scope, groupKeyScopeGroupShared);
      expect(envelopeCall.keyEnvelopes, hasLength(2));
      expect(
        envelopeCall.keyEnvelopes
            .map((Map<String, dynamic> envelope) => envelope['recipient_device_identifier'])
            .toSet(),
        <String>{'device-123', 'device-456'},
      );
    });

    test('registerManagedDevice adds device to group and provisions an envelope', () async {
      final FakeFlutterSecureStorage secureStorage = FakeFlutterSecureStorage();
      final FakeGroupContentKeyStore groupContentKeyStore = FakeGroupContentKeyStore();
      const List<int> contentKeyBytes = <int>[
        5, 4, 3, 2, 1, 0, 9, 8,
        7, 6, 5, 4, 3, 2, 1, 0,
        1, 3, 5, 7, 9, 11, 13, 15,
        2, 4, 6, 8, 10, 12, 14, 16,
      ];
      await groupContentKeyStore.saveGroupContentKey('group-1', contentKeyBytes);
      await groupContentKeyStore.saveGroupContentKey(
        'group-1',
        List<int>.generate(32, (int index) => 32 - index),
        scope: groupKeyScopeManagerRoster,
      );
      final _KeyMaterial memberKeyMaterial = await _createKeyMaterial();
      final FakeManagerApiService managerApiService = FakeManagerApiService(
        baseUrl: 'http://manager',
        groupDevicesById: <String, List<MainManagerGroupDevice>>{
          'group-1': <MainManagerGroupDevice>[
            MainManagerGroupDevice(
              deviceIdentifier: 'member-1',
              encryptedMemberName: 'enc',
              publicKey: memberKeyMaterial.publicKeyB64,
              publicKeyFingerprint: '',
            ),
          ],
        },
      );
      final DeviceRegistrationService service = DeviceRegistrationService(
        secureStorage: secureStorage,
        installationIdStore: FixedInstallationIdStore('manager-device'),
        groupContentKeyStore: groupContentKeyStore,
      );

      await service.registerManagedDevice(
        managerApiService: managerApiService,
        registrationData: DeviceRegistrationData(
          deviceIdentifier: 'member-1',
          memberName: 'Alice',
          publicKey: memberKeyMaterial.publicKeyB64,
          publicKeyAlgorithm: 'x25519',
        ),
        groupId: 'group-1',
      );

      expect(managerApiService.registerDeviceCalls, hasLength(1));
      expect(managerApiService.addDeviceCalls, hasLength(1));
      expect(managerApiService.envelopeCalls, hasLength(1));
      expect(managerApiService.addDeviceCalls.single.encryptedMemberName, isNotEmpty);

      final CreateEnvelopeCall envelopeCall = managerApiService.envelopeCalls.single;
      final Map<String, dynamic> envelope = envelopeCall.keyEnvelopes.single;
      final List<int> unwrappedKey = await EyesOnlyCrypto.unwrapWithPrivateKey(
        envelope['encrypted_group_key'] as String,
        memberKeyMaterial.privateKeyBytes,
        memberKeyMaterial.publicKeyBytes,
        groupKeyEncryptionHkdfInfo,
      );
      expect(unwrappedKey, contentKeyBytes);
      expect(envelope['recipient_device_identifier'], 'member-1');
      expect(envelopeCall.groupId, 'group-1');
      expect(envelopeCall.scope, groupKeyScopeGroupShared);
    });

    test('registerManagedDevice fails when the manager device lacks the group key', () async {
      final FakeManagerApiService managerApiService = FakeManagerApiService(
        baseUrl: 'http://manager',
      );
      final DeviceRegistrationService service = DeviceRegistrationService(
        secureStorage: FakeFlutterSecureStorage(),
        installationIdStore: FixedInstallationIdStore('manager-device'),
        groupContentKeyStore: FakeGroupContentKeyStore(),
      );

      await expectLater(
        () => service.registerManagedDevice(
          managerApiService: managerApiService,
          registrationData: const DeviceRegistrationData(
            deviceIdentifier: 'member-1',
            memberName: 'Alice',
            publicKey: 'public-key',
            publicKeyAlgorithm: 'x25519',
          ),
          groupId: 'group-1',
        ),
        throwsA(isA<ApiException>()),
      );
    });
  });
}

String _jwtWithUserId(int userId) {
  final String header = base64Url.encode(utf8.encode('{"alg":"none","typ":"JWT"}')).replaceAll('=', '');
  final String payload = base64Url
      .encode(utf8.encode('{"user_id":$userId}'))
      .replaceAll('=', '');
  return '$header.$payload.signature';
}

Future<_KeyMaterial> _createKeyMaterial() async {
  final KeyPair keyPair = await X25519().newKeyPair();
  final SimpleKeyPairData keyPairData =
      await keyPair.extract() as SimpleKeyPairData;
  return _KeyMaterial(
    privateKeyB64: base64Encode(keyPairData.bytes),
    publicKeyB64: base64Encode(keyPairData.publicKey.bytes),
    privateKeyBytes: keyPairData.bytes,
    publicKeyBytes: keyPairData.publicKey.bytes,
  );
}

class _KeyMaterial {
  const _KeyMaterial({
    required this.privateKeyB64,
    required this.publicKeyB64,
    required this.privateKeyBytes,
    required this.publicKeyBytes,
  });

  final String privateKeyB64;
  final String publicKeyB64;
  final List<int> privateKeyBytes;
  final List<int> publicKeyBytes;
}

class RegisterDeviceCall {
  const RegisterDeviceCall({
    required this.deviceIdentifier,
    required this.publicKey,
    required this.publicKeyAlgorithm,
    required this.ownerUser,
  });

  final String deviceIdentifier;
  final String publicKey;
  final String publicKeyAlgorithm;
  final int? ownerUser;
}

class AddDeviceCall {
  const AddDeviceCall({
    required this.deviceIdentifier,
    required this.groupId,
    required this.encryptedMemberName,
  });

  final String deviceIdentifier;
  final String groupId;
  final String encryptedMemberName;
}

class CreateEnvelopeCall {
  const CreateEnvelopeCall({
    required this.groupId,
    required this.scope,
    required this.keyEnvelopes,
  });

  final String groupId;
  final String scope;
  final List<Map<String, dynamic>> keyEnvelopes;
}

class FakeManagerApiService extends ManagerApiService {
  FakeManagerApiService({
    required super.baseUrl,
    this.accessTokenValue,
    this.mainManagerGroups = const <Map<String, dynamic>>[],
    Map<String, List<MainManagerGroupDevice>>? groupDevicesById,
  }) : _groupDevicesById =
           groupDevicesById ?? <String, List<MainManagerGroupDevice>>{};

  final String? accessTokenValue;
  final List<Map<String, dynamic>> mainManagerGroups;
  final Map<String, List<MainManagerGroupDevice>> _groupDevicesById;
  final List<RegisterDeviceCall> registerDeviceCalls = <RegisterDeviceCall>[];
  final List<AddDeviceCall> addDeviceCalls = <AddDeviceCall>[];
  final List<CreateEnvelopeCall> envelopeCalls = <CreateEnvelopeCall>[];

  @override
  String? get accessToken => accessTokenValue;

  @override
  Future<void> addDeviceToGroup({
    required String deviceIdentifier,
    required String groupId,
    required String encryptedMemberName,
    String endpoint = '',
  }) async {
    addDeviceCalls.add(
      AddDeviceCall(
        deviceIdentifier: deviceIdentifier,
        groupId: groupId,
        encryptedMemberName: encryptedMemberName,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> createGroupKeyEnvelope({
    required String groupId,
    required List<Map<String, dynamic>> keyEnvelopes,
    String scope = groupKeyScopeGroupShared,
    String endpoint = '',
  }) async {
    envelopeCalls.add(
      CreateEnvelopeCall(
        groupId: groupId,
        scope: scope,
        keyEnvelopes: keyEnvelopes,
      ),
    );
    return <String, dynamic>{};
  }

  @override
  Future<List<MainManagerGroupDevice>> getMainManagerGroupDevices({
    required String groupId,
  }) async {
    return _groupDevicesById[groupId] ?? const <MainManagerGroupDevice>[];
  }

  @override
  Future<List<Map<String, dynamic>>> getMainManagerGroups() async {
    return mainManagerGroups;
  }

  @override
  Future<void> registerDevice({
    required String deviceIdentifier,
    required String publicKey,
    required String publicKeyAlgorithm,
    int? ownerUser,
    String endpoint = '',
  }) async {
    registerDeviceCalls.add(
      RegisterDeviceCall(
        deviceIdentifier: deviceIdentifier,
        publicKey: publicKey,
        publicKeyAlgorithm: publicKeyAlgorithm,
        ownerUser: ownerUser,
      ),
    );
  }
}

class FakeGroupContentKeyStore extends GroupContentKeyStore {
  final Map<String, List<int>> _keys = <String, List<int>>{};

  String _compositeKey(String groupId, String scope) => '$scope::$groupId';

  @override
  Future<List<int>?> readGroupContentKey(String groupId, {String scope = groupKeyScopeGroupShared}) async {
    return _keys[_compositeKey(groupId, scope)];
  }

  @override
  Future<void> saveGroupContentKey(String groupId, List<int> keyBytes, {String scope = groupKeyScopeGroupShared}) async {
    _keys[_compositeKey(groupId, scope)] = List<int>.from(keyBytes);
  }
}

class FixedInstallationIdStore extends InstallationIdStore {
  FixedInstallationIdStore(this.installationId);

  final String installationId;

  @override
  Future<String> getOrCreateInstallationId() async => installationId;
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