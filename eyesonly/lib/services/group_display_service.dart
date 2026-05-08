import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:eyesonly/services/crypto/eyes_only_crypto.dart';
import 'package:eyesonly/services/device/api_service.dart';
import 'package:eyesonly/services/manager/device_registration_keys.dart';
import 'package:eyesonly/services/manager/group_content_key_store.dart';
import 'package:eyesonly/services/manager/group_name_cipher.dart';
import 'package:eyesonly/services/manager/group_scoped_metadata_cipher.dart';

typedef DeviceGroupKeyEnvelopeFetcher =
    Future<List<DeviceGroupKeyEnvelope>> Function(
      String baseUrl,
      List<String> groupIds,
      List<String>? scopes,
    );

class GroupDisplayService {
  GroupDisplayService({
    GroupContentKeyStore? groupContentKeyStore,
    FlutterSecureStorage? secureStorage,
    DeviceGroupKeyEnvelopeFetcher? groupKeyEnvelopeFetcher,
  }) : _groupContentKeyStore =
           groupContentKeyStore ?? GroupContentKeyStore(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _groupKeyEnvelopeFetcher = groupKeyEnvelopeFetcher;

  final GroupContentKeyStore _groupContentKeyStore;
  final FlutterSecureStorage _secureStorage;
  final DeviceGroupKeyEnvelopeFetcher? _groupKeyEnvelopeFetcher;
  GroupScopedMetadataCipher get _groupScopedMetadataCipher =>
      GroupScopedMetadataCipher(groupContentKeyStore: _groupContentKeyStore);

  Future<void> syncGroupKeysFromDeviceEndpoint({
    required String baseUrl,
    required Iterable<String> groupIds,
    List<String>? scopes,
  }) async {
    final List<String> normalizedGroupIds = groupIds
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedGroupIds.isEmpty) {
      return;
    }

    final String? privateKeyB64 =
        await _secureStorage.read(key: DeviceRegistrationKeys.privateKey);
    final String? publicKeyB64 =
        await _secureStorage.read(key: DeviceRegistrationKeys.publicKey);
    if (privateKeyB64 == null ||
        privateKeyB64.isEmpty ||
        publicKeyB64 == null ||
        publicKeyB64.isEmpty) {
      return;
    }

    final List<DeviceGroupKeyEnvelope> envelopes =
      await (_groupKeyEnvelopeFetcher != null
        ? _groupKeyEnvelopeFetcher(baseUrl, normalizedGroupIds, scopes)
        : DeviceApiService(
          baseUrl: baseUrl,
          ).getGroupKeyEnvelopes(groupIds: normalizedGroupIds, scopes: scopes));
    final List<int> privateKeyBytes = base64Decode(privateKeyB64);
    final List<int> publicKeyBytes = base64Decode(publicKeyB64);

    for (final DeviceGroupKeyEnvelope envelope in envelopes) {
      try {
        final List<int> contentKeyBytes = await EyesOnlyCrypto.unwrapWithPrivateKey(
          envelope.encryptedGroupKey,
          privateKeyBytes,
          publicKeyBytes,
          groupKeyEncryptionHkdfInfo,
        );
        await _groupContentKeyStore.saveGroupContentKey(
          envelope.groupId,
          contentKeyBytes,
          scope: envelope.scope?.trim().isNotEmpty == true
              ? envelope.scope!.trim()
              : groupKeyScopeGroupShared,
        );
      } catch (_) {
        // Skip envelopes that cannot be unwrapped by this device.
      }
    }
  }

  Future<String?> tryDecryptGroupName({
    required String groupId,
    required String encryptedName,
    required String nameNonce,
  }) async {
    final String normalizedGroupId = groupId.trim();
    final String normalizedEncryptedName = encryptedName.trim();
    final String normalizedNameNonce = nameNonce.trim();

    if (normalizedGroupId.isEmpty ||
        normalizedEncryptedName.isEmpty ||
        normalizedNameNonce.isEmpty) {
      return null;
    }

    final List<int>? keyBytes =
        await _groupContentKeyStore.readGroupContentKey(
          normalizedGroupId,
          scope: groupKeyScopeGroupShared,
        );
    if (keyBytes == null) {
      return null;
    }

    try {
      final List<int> plainBytes = await EyesOnlyCrypto.symmetricDecrypt(
        normalizedEncryptedName,
        normalizedNameNonce,
        keyBytes,
      );
      final String name = utf8.decode(plainBytes).trim();
      return name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }

  Future<String?> tryDecryptMemberName({
    required String groupId,
    required String encryptedMemberName,
  }) async {
    final String normalizedGroupId = groupId.trim();
    final String normalizedPayload = encryptedMemberName.trim();
    if (normalizedGroupId.isEmpty || normalizedPayload.isEmpty) {
      return null;
    }

    try {
      final String name = await _groupScopedMetadataCipher.decryptForGroup(
        groupId: normalizedGroupId,
        scope: groupKeyScopeManagerRoster,
        encryptedPayload: normalizedPayload,
      );
      return name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }
}