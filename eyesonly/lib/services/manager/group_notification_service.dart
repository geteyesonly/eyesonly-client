import 'dart:convert';

import '../api_exception.dart';
import '../crypto/eyes_only_crypto.dart';
import '../group_display_service.dart';
import 'api_service.dart';
import 'group_content_key_store.dart';

class GroupNotificationResult {
  const GroupNotificationResult({
    required this.notifiedCount,
    required this.skippedCount,
  });

  final int notifiedCount;
  final int skippedCount;

  factory GroupNotificationResult.fromJson(Map<String, dynamic> json) {
    return GroupNotificationResult(
      notifiedCount: (json['notified_count'] as num?)?.toInt() ?? 0,
      skippedCount: (json['skipped_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class GroupNotificationService {
  GroupNotificationService({
    ManagerApiService? managerApiService,
    GroupDisplayService? groupDisplayService,
    GroupContentKeyStore? groupContentKeyStore,
  }) : _managerApiService = managerApiService,
       _groupDisplayService = groupDisplayService ?? GroupDisplayService(),
       _groupContentKeyStore = groupContentKeyStore ?? GroupContentKeyStore();

  final ManagerApiService? _managerApiService;
  final GroupDisplayService _groupDisplayService;
  final GroupContentKeyStore _groupContentKeyStore;

  static const String fixedNotificationMessage =
      'There are new images for you';

  Future<GroupNotificationResult> sendGroupNotification({
    required String baseUrl,
    required String groupId,
  }) async {
    final String normalizedGroupId = groupId.trim();
    if (normalizedGroupId.isEmpty) {
      throw ApiException('Group is missing for this notification request.');
    }

    final ManagerApiService managerApiService =
        _managerApiService ?? ManagerApiService(baseUrl: baseUrl);
    await managerApiService.hydrateTokens();
    await _groupDisplayService.syncGroupKeysFromDeviceEndpoint(
      baseUrl: baseUrl,
      groupIds: <String>[normalizedGroupId],
      scopes: const <String>[groupKeyScopeGroupShared],
    );

    final List<int>? contentKeyBytes = await _groupContentKeyStore
        .readGroupContentKey(
          normalizedGroupId,
          scope: groupKeyScopeGroupShared,
        );
    if (contentKeyBytes == null) {
      throw ApiException(
        'This group key is not available on this device yet.',
      );
    }

    final ({String ciphertext, String nonce}) encryptedPayload =
        await EyesOnlyCrypto.symmetricEncrypt(
          utf8.encode(fixedNotificationMessage),
          contentKeyBytes,
        );

    final Map<String, dynamic> response = await managerApiService.notifyGroup(
      groupId: normalizedGroupId,
      encryptedPayload: encryptedPayload.ciphertext,
      nonce: encryptedPayload.nonce,
      encryptionAlgorithm: EyesOnlyCrypto.symmetricAlgorithm,
    );

    return GroupNotificationResult.fromJson(response);
  }
}