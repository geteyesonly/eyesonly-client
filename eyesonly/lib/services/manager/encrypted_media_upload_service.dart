import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../api_exception.dart';
import '../crypto/eyes_only_crypto.dart';
import 'api_service.dart';

const String mediaContentKeyEncryptionHkdfInfo =
    'eyesonly-media-content-key-encryption-v1';

class EncryptedMediaUploadService {
  EncryptedMediaUploadService({ManagerApiService? managerApiService})
    : _managerApiService = managerApiService;

  final ManagerApiService? _managerApiService;

  Future<UploadEncryptedBlobResponse> uploadImageForGroup({
    required String baseUrl,
    required String groupId,
    required Uint8List imageBytes,
    String? caption,
    DateTime? expiresAt,
  }) async {
    final ManagerApiService managerApiService =
        _managerApiService ?? ManagerApiService(baseUrl: baseUrl);
    await managerApiService.hydrateTokens();

    final List<MainManagerGroupDevice> devices = await managerApiService
        .getMainManagerGroupDevices(groupId: groupId);
    final List<MainManagerGroupDevice> recipients = devices.where((
      MainManagerGroupDevice device,
    ) {
      final String deviceIdentifier = device.deviceIdentifier.trim();
      final String publicKey = device.publicKey.trim();
      return deviceIdentifier.isNotEmpty && publicKey.isNotEmpty;
    }).toList();

    if (recipients.isEmpty) {
      throw ApiException('No recipient devices are available for this group.');
    }

    final List<int> contentKeyBytes = await EyesOnlyCrypto.generateKey();
    final ({String ciphertext, String nonce}) encryptedImage =
        await EyesOnlyCrypto.symmetricEncrypt(imageBytes, contentKeyBytes);
    final Uint8List encryptedBlobBytes = Uint8List.fromList(
      base64Decode(encryptedImage.ciphertext),
    );

    final List<Map<String, dynamic>> recipientEnvelopes =
        await _buildRecipientEnvelopes(
          recipients: recipients,
          contentKeyBytes: contentKeyBytes,
        );

    final String? encryptedCaption = await _encryptCaption(
      caption: caption,
      contentKeyBytes: contentKeyBytes,
    );

    return managerApiService.uploadEncryptedBlob(
      request: UploadEncryptedBlobRequest(
        groupId: groupId,
        encryptedBlobBytes: encryptedBlobBytes,
        payloadNonce: encryptedImage.nonce,
        recipientEnvelopes: recipientEnvelopes,
        encryptedCaption: encryptedCaption,
        encryptionAlgorithm: EyesOnlyCrypto.symmetricAlgorithm,
        expiresAt: expiresAt,
        clientCiphertextHashSha256: await _sha256Hex(encryptedBlobBytes),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _buildRecipientEnvelopes({
    required List<MainManagerGroupDevice> recipients,
    required List<int> contentKeyBytes,
  }) async {
    final List<Map<String, dynamic>> envelopes = <Map<String, dynamic>>[];

    for (final MainManagerGroupDevice recipient in recipients) {
      final String publicKeyAlgorithm =
          recipient.publicKeyAlgorithm?.trim().toLowerCase() ?? 'x25519';
      if (publicKeyAlgorithm != 'x25519') {
        continue;
      }

      final String recipientKeyFingerprint =
          recipient.publicKeyFingerprint.trim().isNotEmpty
          ? recipient.publicKeyFingerprint.trim()
          : await EyesOnlyCrypto.publicKeyFingerprint(recipient.publicKey);

      final String encryptedContentKey = await EyesOnlyCrypto.wrapForPublicKey(
        contentKeyBytes,
        recipient.publicKey,
        mediaContentKeyEncryptionHkdfInfo,
      );

      envelopes.add(<String, dynamic>{
        'recipient_device_identifier': recipient.deviceIdentifier.trim(),
        'key_wrap_algorithm': EyesOnlyCrypto.asymmetricAlgorithm,
        'recipient_key_fingerprint': recipientKeyFingerprint,
        'encrypted_content_key': encryptedContentKey,
      });
    }

    if (envelopes.isEmpty) {
      throw ApiException(
        'No compatible recipient public keys are available for this group.',
      );
    }

    return envelopes;
  }

  Future<String?> _encryptCaption({
    required String? caption,
    required List<int> contentKeyBytes,
  }) async {
    final String normalizedCaption = caption?.trim() ?? '';
    if (normalizedCaption.isEmpty) {
      return null;
    }

    final ({String ciphertext, String nonce}) encryptedCaption =
        await EyesOnlyCrypto.symmetricEncrypt(
          utf8.encode(normalizedCaption),
          contentKeyBytes,
        );

    return base64Encode(
      utf8.encode(
        jsonEncode(<String, String>{
          'algorithm': EyesOnlyCrypto.symmetricAlgorithm,
          'nonce': encryptedCaption.nonce,
          'ciphertext': encryptedCaption.ciphertext,
        }),
      ),
    );
  }

  Future<String> _sha256Hex(List<int> bytes) async {
    final Hash hash = await Sha256().hash(bytes);
    return hash.bytes
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
