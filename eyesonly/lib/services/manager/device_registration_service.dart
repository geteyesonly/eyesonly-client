import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api_exception.dart';
import '../crypto/eyes_only_crypto.dart';
import '../installation_id_store.dart';
import 'api_service.dart';
import '../device/api_service.dart' as device;
import '../device/allowed_algorithms.dart';
import 'device_registration_keys.dart';
import 'group_content_key_store.dart';
import 'group_name_cipher.dart';
import 'group_scoped_metadata_cipher.dart';

typedef DeviceSelfStatusFetcher = Future<device.DeviceSelfStatus> Function(
  String baseUrl,
);

class DeviceRegistrationData {
  const DeviceRegistrationData({
    required this.deviceIdentifier,
    required this.memberName,
    required this.publicKey,
    required this.publicKeyAlgorithm,
  });

  final String deviceIdentifier;
  final String memberName;
  final String publicKey;
  final String publicKeyAlgorithm;
}

class DeviceJoinRequestData {
  const DeviceJoinRequestData({
    required this.deviceIdentifier,
    required this.publicKey,
    required this.publicKeyAlgorithm,
  });

  final String deviceIdentifier;
  final String publicKey;
  final String publicKeyAlgorithm;
}

class DeviceRegistrationService {
  DeviceRegistrationService({
    FlutterSecureStorage? secureStorage,
    InstallationIdStore? installationIdStore,
    GroupContentKeyStore? groupContentKeyStore,
    DeviceSelfStatusFetcher? deviceSelfStatusFetcher,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _installationIdStore = installationIdStore ?? InstallationIdStore(),
       _groupContentKeyStoreOverride = groupContentKeyStore,
       _deviceSelfStatusFetcher = deviceSelfStatusFetcher;

  static const String _registeredKey = DeviceRegistrationKeys.registered;
  static const String _registeredOwnerNameKey =
      DeviceRegistrationKeys.registeredOwnerName;
  static const String _privateKeyKey = DeviceRegistrationKeys.privateKey;
  static const String _publicKeyKey = DeviceRegistrationKeys.publicKey;
  static const String _publicKeyAlgorithm = defaultPublicKeyAlgorithm;
    static const String managerDeviceRegistrationRequiredMessage =
      'This device is not registered yet. Finish manager device registration before continuing.';

  final FlutterSecureStorage _secureStorage;
  final InstallationIdStore _installationIdStore;
  final GroupContentKeyStore? _groupContentKeyStoreOverride;
  final DeviceSelfStatusFetcher? _deviceSelfStatusFetcher;
  GroupContentKeyStore get _groupContentKeyStore =>
      _groupContentKeyStoreOverride ??
      GroupContentKeyStore(secureStorage: _secureStorage);
  GroupScopedMetadataCipher get _groupScopedMetadataCipher =>
      GroupScopedMetadataCipher(groupContentKeyStore: _groupContentKeyStore);

  Future<String> getCurrentDeviceIdentifier() async {
    return _installationIdStore.getOrCreateInstallationId();
  }

  Future<bool> isCurrentDeviceRegistered({
    required ManagerApiService managerApiService,
  }) async {
    final String managerDeviceIdentifier =
        await _installationIdStore.getOrCreateInstallationId();

    // 1. Try the device-auth status endpoint. This only succeeds when the
    //    device has a device-scoped token (i.e. member devices). For manager
    //    devices that authenticate exclusively via manager JWT this call always
    //    fails – the catch below handles that.
    bool serverRegistered = false;
    try {
      final device.DeviceSelfStatus status =
          await (_deviceSelfStatusFetcher != null
              ? _deviceSelfStatusFetcher(managerApiService.baseUrl)
              : device.DeviceApiService(
                  baseUrl: managerApiService.baseUrl,
                  autoAuthenticate: false,
                ).getSelfStatus());
      serverRegistered =
          status.deviceIdentifier == managerDeviceIdentifier &&
          status.isRegistered;
    } catch (_) {
      // Device-auth check is not applicable for manager devices.
    }

    // 2. If the device-auth check did not confirm registration, query the
    //    manager devices endpoint. This covers the case where another manager
    //    device registered this device externally so the local flag was never
    //    written.
    if (!serverRegistered) {
      try {
        final List<MainManagerGroupDevice> devices =
            await managerApiService.getManagerDevices();
        serverRegistered = devices.any(
          (MainManagerGroupDevice d) =>
              d.deviceIdentifier == managerDeviceIdentifier,
        );
      } catch (_) {
        // Manager-devices endpoint check failed; fall through to the local flag.
      }
    }

    final String? isRegistered = await _secureStorage.read(key: _registeredKey);
    if (serverRegistered) {
      if (isRegistered != 'true') {
        await _secureStorage.write(key: _registeredKey, value: 'true');
      }
      return true;
    }

    return isRegistered == 'true';
  }

  Future<void> requireCurrentDeviceRegistered({
    required ManagerApiService managerApiService,
  }) async {
    final bool isRegistered = await isCurrentDeviceRegistered(
      managerApiService: managerApiService,
    );
    if (!isRegistered) {
      throw ApiException(managerDeviceRegistrationRequiredMessage);
    }
  }

  Future<bool> hasExistingManagerOwnedDevice({
    required ManagerApiService managerApiService,
  }) async {
    final String currentDeviceIdentifier =
        await _installationIdStore.getOrCreateInstallationId();
    final List<MainManagerGroupDevice> devices =
        await managerApiService.getManagerDevices();
    return devices.any(
      (MainManagerGroupDevice d) =>
          d.deviceIdentifier.trim().isNotEmpty &&
          d.deviceIdentifier != currentDeviceIdentifier,
    );
  }

  Future<void> ensureRegistered({
    required ManagerApiService managerApiService,
    required String username,
  }) async {
    final String managerDeviceIdentifier =
        await _installationIdStore.getOrCreateInstallationId();
    if (await isCurrentDeviceRegistered(managerApiService: managerApiService)) {
      return;
    }

    // If not registered on server, proceed to register
    final ({String publicKey, String privateKey}) managerKeyMaterial =
        await _getOrCreateKeyMaterial();
    final int? ownerUserId = _extractOwnerUserId(managerApiService.accessToken);

    await managerApiService.registerDevice(
      deviceIdentifier: managerDeviceIdentifier,
      publicKey: managerKeyMaterial.publicKey,
      publicKeyAlgorithm: _publicKeyAlgorithm,
      // Only the manager's own device is linked to the logged-in manager.
      ownerUser: ownerUserId,
    );

    await _secureStorage.write(key: _registeredKey, value: 'true');
    await _secureStorage.write(key: _registeredOwnerNameKey, value: username.trim());
  }

  Future<DeviceRegistrationData> createRegistrationDataForDevice({
    required String deviceIdentifier,
    required String ownerName,
  }) async {
    final ({String publicKey, String privateKey}) keyMaterial =
        await _createNewKeyMaterial();

    return DeviceRegistrationData(
      deviceIdentifier: deviceIdentifier,
      memberName: ownerName,
      publicKey: keyMaterial.publicKey,
      publicKeyAlgorithm: _publicKeyAlgorithm,
    );
  }

  Future<DeviceRegistrationData> createRegistrationDataFromExistingDevice({
    required String deviceIdentifier,
    required String ownerName,
    required String publicKey,
    required String publicKeyAlgorithm,
  }) async {
    return DeviceRegistrationData(
      deviceIdentifier: deviceIdentifier,
      memberName: ownerName,
      publicKey: publicKey,
      publicKeyAlgorithm: publicKeyAlgorithm,
    );
  }

  Future<DeviceJoinRequestData> getOrCreateJoinRequestData() async {
    final String deviceIdentifier =
        await _installationIdStore.getOrCreateInstallationId();
    final ({String publicKey, String privateKey}) keyMaterial =
        await _getOrCreateKeyMaterial();

    return DeviceJoinRequestData(
      deviceIdentifier: deviceIdentifier,
      publicKey: keyMaterial.publicKey,
      publicKeyAlgorithm: _publicKeyAlgorithm,
    );
  }

  Future<void> ensureCurrentDeviceAddedToMainManagerGroups({
    required ManagerApiService managerApiService,
    String? username,
  }) async {
    final String deviceIdentifier =
        await _installationIdStore.getOrCreateInstallationId();
    final String normalizedUsername = username?.trim() ??
        (await _secureStorage.read(key: _registeredOwnerNameKey))?.trim() ?? '';
    final List<Map<String, dynamic>> mainManagerGroups =
        await managerApiService.getMainManagerGroups();

    for (final Map<String, dynamic> group in mainManagerGroups) {
      final String groupId = (group['uuid'] as String?)?.trim() ?? '';
      if (groupId.isEmpty) {
        continue;
      }

      List<MainManagerGroupDevice> devices =
          await managerApiService.getMainManagerGroupDevices(groupId: groupId);
      final bool hasManagerRosterKey =
          await _groupContentKeyStore.readGroupContentKey(
            groupId,
            scope: groupKeyScopeManagerRoster,
          ) !=
          null;
      final bool hasGroupSharedKey =
          await _groupContentKeyStore.readGroupContentKey(
            groupId,
            scope: groupKeyScopeGroupShared,
          ) !=
          null;
      final bool isCurrentDeviceLinked = devices.any(
        (MainManagerGroupDevice device) =>
            device.deviceIdentifier == deviceIdentifier,
      );
      if (!isCurrentDeviceLinked) {
        if (!hasManagerRosterKey || normalizedUsername.isEmpty) {
          continue;
        }
        final String encryptedMemberName =
            await _groupScopedMetadataCipher.encryptForGroup(
              groupId: groupId,
              scope: groupKeyScopeManagerRoster,
              plaintext: normalizedUsername,
            );
        await managerApiService.addDeviceToGroup(
          deviceIdentifier: deviceIdentifier,
          groupId: groupId,
          encryptedMemberName: encryptedMemberName,
        );

        devices = await managerApiService.getMainManagerGroupDevices(
          groupId: groupId,
        );
      }

      if (isCurrentDeviceLinked && hasManagerRosterKey && normalizedUsername.isNotEmpty) {
        final String encryptedMemberName =
            await _groupScopedMetadataCipher.encryptForGroup(
              groupId: groupId,
              scope: groupKeyScopeManagerRoster,
              plaintext: normalizedUsername,
            );
        await managerApiService.addDeviceToGroup(
          deviceIdentifier: deviceIdentifier,
          groupId: groupId,
          encryptedMemberName: encryptedMemberName,
        );
      }

      if (hasGroupSharedKey) {
        await _provisionKnownGroupKeyEnvelopesForDevices(
          managerApiService: managerApiService,
          groupId: groupId,
          scope: groupKeyScopeGroupShared,
          devices: devices,
        );
      }

      if (hasManagerRosterKey) {
        final List<MainManagerGroupDevice> currentDeviceRecord = devices
            .where((MainManagerGroupDevice device) =>
                device.deviceIdentifier == deviceIdentifier)
            .toList();
        await _provisionKnownGroupKeyEnvelopesForDevices(
          managerApiService: managerApiService,
          groupId: groupId,
          scope: groupKeyScopeManagerRoster,
          devices: currentDeviceRecord,
        );
      }
    }
  }

  Future<void> _provisionKnownGroupKeyEnvelopesForDevices({
    required ManagerApiService managerApiService,
    required String groupId,
    required String scope,
    required List<MainManagerGroupDevice> devices,
  }) async {
    final List<int>? contentKeyBytes = await _groupContentKeyStore
        .readGroupContentKey(groupId, scope: scope);
    if (contentKeyBytes == null || devices.isEmpty) {
      return;
    }

    final List<Map<String, dynamic>> keyEnvelopes = <Map<String, dynamic>>[];
    for (final MainManagerGroupDevice device in devices) {
      final String publicKey = device.publicKey.trim();
      if (device.deviceIdentifier.trim().isEmpty || publicKey.isEmpty) {
        continue;
      }

      final String algorithm =
          device.publicKeyAlgorithm?.trim().toLowerCase() ?? 'x25519';
      if (algorithm != 'x25519') {
        continue;
      }

      final String recipientKeyFingerprint =
          device.publicKeyFingerprint.trim().isNotEmpty
          ? device.publicKeyFingerprint.trim()
          : await EyesOnlyCrypto.publicKeyFingerprint(publicKey);

      final String encryptedGroupKey = await EyesOnlyCrypto.wrapForPublicKey(
        contentKeyBytes,
        publicKey,
        groupKeyEncryptionHkdfInfo,
      );

      keyEnvelopes.add(<String, dynamic>{
        'recipient_device_identifier': device.deviceIdentifier,
        'key_wrap_algorithm': EyesOnlyCrypto.asymmetricAlgorithm,
        'recipient_key_fingerprint': recipientKeyFingerprint,
        'encrypted_group_key': encryptedGroupKey,
      });
    }

    if (keyEnvelopes.isEmpty) {
      return;
    }

    await managerApiService.createGroupKeyEnvelope(
      groupId: groupId,
      scope: scope,
      keyEnvelopes: keyEnvelopes,
    );
  }

  Future<void> registerManagerDeviceAndProvisionKeys({
    required ManagerApiService managerApiService,
    required DeviceRegistrationData registrationData,
  }) async {
    final int? ownerUserId = _extractOwnerUserId(managerApiService.accessToken);
    if (ownerUserId == null) {
      throw ApiException(
        'Could not read the manager user ID from the session token. Please log in again.',
      );
    }

    await managerApiService.registerDevice(
      deviceIdentifier: registrationData.deviceIdentifier,
      publicKey: registrationData.publicKey,
      publicKeyAlgorithm: registrationData.publicKeyAlgorithm,
      ownerUser: ownerUserId,
    );

    // Add the newly registered device to all main-manager groups where this
    // device holds the necessary group keys, provisioning encrypted key
    // envelopes for both the roster and shared scopes.
    final List<Map<String, dynamic>> mainManagerGroups =
        await managerApiService.getMainManagerGroups();
    for (final Map<String, dynamic> group in mainManagerGroups) {
      final String groupId = (group['uuid'] as String?)?.trim() ?? '';
      if (groupId.isEmpty) {
        continue;
      }

      final List<int>? rosterKeyBytes =
          await _groupContentKeyStore.readGroupContentKey(
        groupId,
        scope: groupKeyScopeManagerRoster,
      );
      final List<int>? sharedKeyBytes =
          await _groupContentKeyStore.readGroupContentKey(
        groupId,
        scope: groupKeyScopeGroupShared,
      );
      if (rosterKeyBytes == null || sharedKeyBytes == null) {
        continue;
      }

      final String encryptedMemberName =
          await _groupScopedMetadataCipher.encryptForGroup(
        groupId: groupId,
        scope: groupKeyScopeManagerRoster,
        plaintext: registrationData.memberName,
      );
      await managerApiService.addDeviceToGroup(
        deviceIdentifier: registrationData.deviceIdentifier,
        groupId: groupId,
        encryptedMemberName: encryptedMemberName,
        isManager: true,
      );

      final MainManagerGroupDevice deviceRecord = await _waitForDeviceInGroup(
        managerApiService: managerApiService,
        groupId: groupId,
        deviceIdentifier: registrationData.deviceIdentifier,
      );
      final String resolvedFingerprint =
          deviceRecord.publicKeyFingerprint.trim().isNotEmpty
              ? deviceRecord.publicKeyFingerprint.trim()
              : await EyesOnlyCrypto.publicKeyFingerprint(
                  registrationData.publicKey,
                );

      final String encryptedRosterKey = await EyesOnlyCrypto.wrapForPublicKey(
        rosterKeyBytes,
        registrationData.publicKey,
        groupKeyEncryptionHkdfInfo,
      );
      await managerApiService.createGroupKeyEnvelope(
        groupId: groupId,
        scope: groupKeyScopeManagerRoster,
        keyEnvelopes: <Map<String, dynamic>>[
          <String, dynamic>{
            'recipient_device_identifier': registrationData.deviceIdentifier,
            'key_wrap_algorithm': EyesOnlyCrypto.asymmetricAlgorithm,
            'recipient_key_fingerprint': resolvedFingerprint,
            'encrypted_group_key': encryptedRosterKey,
          },
        ],
      );

      final String encryptedSharedKey = await EyesOnlyCrypto.wrapForPublicKey(
        sharedKeyBytes,
        registrationData.publicKey,
        groupKeyEncryptionHkdfInfo,
      );
      await managerApiService.createGroupKeyEnvelope(
        groupId: groupId,
        scope: groupKeyScopeGroupShared,
        keyEnvelopes: <Map<String, dynamic>>[
          <String, dynamic>{
            'recipient_device_identifier': registrationData.deviceIdentifier,
            'key_wrap_algorithm': EyesOnlyCrypto.asymmetricAlgorithm,
            'recipient_key_fingerprint': resolvedFingerprint,
            'encrypted_group_key': encryptedSharedKey,
          },
        ],
      );
    }
  }

  Future<void> addExternalManagerDeviceToGroup({
    required ManagerApiService managerApiService,
    required DeviceRegistrationData registrationData,
    required String groupId,
    required int ownerUser,
    bool isManager = false,
  }) async {
    await managerApiService.registerDevice(
      deviceIdentifier: registrationData.deviceIdentifier,
      publicKey: registrationData.publicKey,
      publicKeyAlgorithm: registrationData.publicKeyAlgorithm,
      ownerUser: ownerUser,
    );

    final String fingerprint = await EyesOnlyCrypto.publicKeyFingerprint(
      registrationData.publicKey,
    );

    final List<int>? rosterKeyBytes =
        await _groupContentKeyStore.readGroupContentKey(
      groupId,
      scope: groupKeyScopeManagerRoster,
    );
    final List<int>? sharedKeyBytes =
        await _groupContentKeyStore.readGroupContentKey(
      groupId,
      scope: groupKeyScopeGroupShared,
    );

    if (rosterKeyBytes == null || sharedKeyBytes == null) {
      throw ApiException(
        'This manager device does not have the group keys needed to add a manager device.',
      );
    }

    final String encryptedMemberName =
        await _groupScopedMetadataCipher.encryptForGroup(
      groupId: groupId,
      scope: groupKeyScopeManagerRoster,
      plaintext: registrationData.memberName,
    );
    await managerApiService.addDeviceToGroup(
      deviceIdentifier: registrationData.deviceIdentifier,
      groupId: groupId,
      encryptedMemberName: encryptedMemberName,
      isManager: isManager,
    );

    final MainManagerGroupDevice deviceRecord = await _waitForDeviceInGroup(
      managerApiService: managerApiService,
      groupId: groupId,
      deviceIdentifier: registrationData.deviceIdentifier,
    );
    final String resolvedFingerprint =
        deviceRecord.publicKeyFingerprint.trim().isNotEmpty
        ? deviceRecord.publicKeyFingerprint.trim()
        : fingerprint;

    final String encryptedRosterKey = await EyesOnlyCrypto.wrapForPublicKey(
      rosterKeyBytes,
      registrationData.publicKey,
      groupKeyEncryptionHkdfInfo,
    );
    await managerApiService.createGroupKeyEnvelope(
      groupId: groupId,
      scope: groupKeyScopeManagerRoster,
      keyEnvelopes: <Map<String, dynamic>>[
        <String, dynamic>{
          'recipient_device_identifier': registrationData.deviceIdentifier,
          'key_wrap_algorithm': EyesOnlyCrypto.asymmetricAlgorithm,
          'recipient_key_fingerprint': resolvedFingerprint,
          'encrypted_group_key': encryptedRosterKey,
        },
      ],
    );

    final String encryptedSharedKey = await EyesOnlyCrypto.wrapForPublicKey(
      sharedKeyBytes,
      registrationData.publicKey,
      groupKeyEncryptionHkdfInfo,
    );
    await managerApiService.createGroupKeyEnvelope(
      groupId: groupId,
      scope: groupKeyScopeGroupShared,
      keyEnvelopes: <Map<String, dynamic>>[
        <String, dynamic>{
          'recipient_device_identifier': registrationData.deviceIdentifier,
          'key_wrap_algorithm': EyesOnlyCrypto.asymmetricAlgorithm,
          'recipient_key_fingerprint': resolvedFingerprint,
          'encrypted_group_key': encryptedSharedKey,
        },
      ],
    );
  }

  Future<void> registerManagedDevice({
    required ManagerApiService managerApiService,
    required DeviceRegistrationData registrationData,
    String? groupId,
  }) async {
    await managerApiService.registerDevice(
      deviceIdentifier: registrationData.deviceIdentifier,
      publicKey: registrationData.publicKey,
      publicKeyAlgorithm: registrationData.publicKeyAlgorithm,
      // Member devices must never be linked to the manager user account.
      ownerUser: null,
    );

    if (groupId != null && groupId.isNotEmpty) {
      final String encryptedMemberName = await _groupScopedMetadataCipher
          .encryptForGroup(
            groupId: groupId,
            scope: groupKeyScopeManagerRoster,
            plaintext: registrationData.memberName,
          );
      await managerApiService.addDeviceToGroup(
        deviceIdentifier: registrationData.deviceIdentifier,
        groupId: groupId,
        encryptedMemberName: encryptedMemberName,
      );
      await _provisionGroupKeyEnvelopeForDevice(
        managerApiService: managerApiService,
        groupId: groupId,
        registrationData: registrationData,
      );
    }
  }

  Future<void> _provisionGroupKeyEnvelopeForDevice({
    required ManagerApiService managerApiService,
    required String groupId,
    required DeviceRegistrationData registrationData,
  }) async {
    final List<int>? contentKeyBytes = await _groupContentKeyStore
        .readGroupContentKey(groupId);
    if (contentKeyBytes == null) {
      throw ApiException(
        'This manager device does not have the group key needed to finish adding this member device.',
      );
    }

    final String publicKeyAlgorithm =
        registrationData.publicKeyAlgorithm.trim().toLowerCase();
    if (publicKeyAlgorithm != 'x25519') {
      throw ApiException(
        'Unsupported device public key algorithm: ${registrationData.publicKeyAlgorithm}',
      );
    }

    final MainManagerGroupDevice deviceRecord =
        await _waitForDeviceInGroup(
          managerApiService: managerApiService,
          groupId: groupId,
          deviceIdentifier: registrationData.deviceIdentifier,
        );

    final String recipientKeyFingerprint =
        deviceRecord.publicKeyFingerprint.trim().isNotEmpty
        ? deviceRecord.publicKeyFingerprint.trim()
        : await EyesOnlyCrypto.publicKeyFingerprint(registrationData.publicKey);

    final String encryptedGroupKey = await EyesOnlyCrypto.wrapForPublicKey(
      contentKeyBytes,
      registrationData.publicKey,
      groupKeyEncryptionHkdfInfo,
    );

    await managerApiService.createGroupKeyEnvelope(
      groupId: groupId,
      scope: groupKeyScopeGroupShared,
      keyEnvelopes: <Map<String, dynamic>>[
        <String, dynamic>{
          'recipient_device_identifier': registrationData.deviceIdentifier,
          'key_wrap_algorithm': EyesOnlyCrypto.asymmetricAlgorithm,
          'recipient_key_fingerprint': recipientKeyFingerprint,
          'encrypted_group_key': encryptedGroupKey,
        },
      ],
    );
  }

  Future<MainManagerGroupDevice> _waitForDeviceInGroup({
    required ManagerApiService managerApiService,
    required String groupId,
    required String deviceIdentifier,
  }) async {
    const int maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final List<MainManagerGroupDevice> devices =
          await managerApiService.getMainManagerGroupDevices(groupId: groupId);
      for (final MainManagerGroupDevice device in devices) {
        if (device.deviceIdentifier == deviceIdentifier) {
          return device;
        }
      }
    }

    throw ApiException(
      'Device was added to the group but could not be confirmed for key provisioning.',
    );
  }

  /// Parses the manager user ID from a JWT access token.
  /// Returns null when the token is absent, malformed, or carries no user ID.
  static int? extractUserIdFromJwt(String? accessToken) {
    return DeviceRegistrationService._parseUserIdFromToken(accessToken);
  }

  int? _extractOwnerUserId(String? accessToken) {
    return DeviceRegistrationService._parseUserIdFromToken(accessToken);
  }

  static int? _parseUserIdFromToken(String? accessToken) {
    final String token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      return null;
    }

    try {
      final List<String> parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }

      final String normalizedPayload = base64Url.normalize(parts[1]);
      final dynamic decoded = jsonDecode(
        utf8.decode(base64Url.decode(normalizedPayload)),
      );
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final dynamic rawUserId = decoded['user_id'] ?? decoded['user'] ?? decoded['id'];
      if (rawUserId is int) {
        return rawUserId;
      }
      if (rawUserId is String) {
        return int.tryParse(rawUserId.trim());
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<({String publicKey, String privateKey})> _getOrCreateKeyMaterial() async {
    final String? existingPublic = await _secureStorage.read(key: _publicKeyKey);
    final String? existingPrivate = await _secureStorage.read(
      key: _privateKeyKey,
    );

    if (existingPublic != null && existingPrivate != null) {
      return (publicKey: existingPublic, privateKey: existingPrivate);
    }

    final ({String publicKey, String privateKey}) keyMaterial =
        await _createNewKeyMaterial();

    await _secureStorage.write(key: _publicKeyKey, value: keyMaterial.publicKey);
    await _secureStorage.write(
      key: _privateKeyKey,
      value: keyMaterial.privateKey,
    );

    return keyMaterial;
  }

  Future<({String publicKey, String privateKey})> _createNewKeyMaterial() async {
    final algorithm = X25519();
    final KeyPair keyPair = await algorithm.newKeyPair();
    final SimpleKeyPairData privateKeyData =
        await keyPair.extract() as SimpleKeyPairData;
    final PublicKey publicKeyRaw = await keyPair.extractPublicKey();
    if (publicKeyRaw is! SimplePublicKey) {
      throw StateError('Unsupported public key type for device registration.');
    }

    return (
      publicKey: base64Encode(publicKeyRaw.bytes),
      privateKey: base64Encode(privateKeyData.bytes),
    );
  }
}