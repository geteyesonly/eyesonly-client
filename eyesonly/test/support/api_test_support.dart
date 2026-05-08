import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'package:eyesonly/services/crypto/eyes_only_crypto.dart';
import 'package:eyesonly/services/device/allowed_algorithms.dart';
import 'package:eyesonly/services/device/api_endpoints.dart';
import 'package:eyesonly/services/device/hkdf_info.dart';
import 'package:eyesonly/services/manager/api_endpoints.dart';
import 'package:eyesonly/services/manager/encrypted_media_upload_service.dart';
import 'package:eyesonly/services/manager/group_name_cipher.dart';

const String apiRoot = String.fromEnvironment(
  'EYESONLY_TEST_API_ROOT',
  defaultValue: 'http://localhost:8080/api/',
);
const String managerUsername = String.fromEnvironment(
  'EYESONLY_TEST_MANAGER_USERNAME',
  defaultValue: '',
);
const String managerPassword = String.fromEnvironment(
  'EYESONLY_TEST_MANAGER_PASSWORD',
  defaultValue: '',
);
const bool enableMutationTests = bool.fromEnvironment(
  'EYESONLY_TEST_ENABLE_MUTATION_TESTS',
  defaultValue: false,
);

String? get managerAuthSkipReason {
  if (managerUsername.trim().isEmpty || managerPassword.trim().isEmpty) {
    return 'Set EYESONLY_TEST_MANAGER_USERNAME and EYESONLY_TEST_MANAGER_PASSWORD.';
  }
  return null;
}

String? get managerMutationSkipReason {
  final String? authSkipReason = managerAuthSkipReason;
  if (authSkipReason != null) {
    return authSkipReason;
  }
  if (!enableMutationTests) {
    return 'Set EYESONLY_TEST_ENABLE_MUTATION_TESTS=true to run mutating endpoint tests.';
  }
  return null;
}

class ManagerSession {
  const ManagerSession({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}

class DeviceKeyMaterial {
  const DeviceKeyMaterial({
    required this.deviceIdentifier,
    required this.publicKeyB64,
    required this.privateKeyB64,
    required this.publicKeyFingerprint,
  });

  final String deviceIdentifier;
  final String publicKeyB64;
  final String privateKeyB64;
  final String publicKeyFingerprint;
}

class DeviceSession {
  const DeviceSession({
    required this.keyMaterial,
    required this.accessToken,
    required this.tokenType,
  });

  final DeviceKeyMaterial keyMaterial;
  final String accessToken;
  final String tokenType;
}

class CreatedGroup {
  const CreatedGroup({
    required this.groupId,
    required this.contentKeyBytes,
  });

  final String groupId;
  final List<int> contentKeyBytes;
}

Uri apiUri(String path, {Map<String, String>? queryParameters}) {
  final String normalizedRoot = apiRoot.endsWith('/') ? apiRoot : '$apiRoot/';
  final String normalizedPath = path.startsWith('/') ? path.substring(1) : path;
  final Uri uri = Uri.parse('$normalizedRoot$normalizedPath');
  if (queryParameters == null || queryParameters.isEmpty) {
    return uri;
  }
  return uri.replace(queryParameters: queryParameters);
}

Map<String, String> jsonHeaders({String? authorization}) {
  return <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (authorization != null && authorization.trim().isNotEmpty)
      'Authorization': authorization.trim(),
  };
}

Map<String, String> deviceJsonHeaders(DeviceSession session) {
  return <String, String>{
    ...jsonHeaders(
      authorization: '${session.tokenType} ${session.accessToken}',
    ),
    'X-Device-Identifier': session.keyMaterial.deviceIdentifier,
  };
}

Map<String, String> deviceBinaryHeaders(DeviceSession session) {
  return <String, String>{
    'Accept': 'application/octet-stream',
    'Authorization': '${session.tokenType} ${session.accessToken}',
    'X-Device-Identifier': session.keyMaterial.deviceIdentifier,
  };
}

Map<String, dynamic> decodeObject(http.Response response) {
  final dynamic decoded = jsonDecode(response.body);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  throw TestFailure('Expected a JSON object but got: ${response.body}');
}

List<Map<String, dynamic>> decodeList(http.Response response) {
  final dynamic decoded = jsonDecode(response.body);
  if (decoded is List) {
    return decoded.whereType<Map<String, dynamic>>().toList();
  }
  throw TestFailure('Expected a JSON list but got: ${response.body}');
}

Future<http.Response> postJson(
  http.Client client,
  String path, {
  required Map<String, dynamic> body,
  Map<String, String>? headers,
}) {
  return client.post(
    apiUri(path),
    headers: headers ?? jsonHeaders(),
    body: jsonEncode(body),
  );
}

Future<ManagerSession> loginManager(http.Client client) async {
  final http.Response loginResponse = await postJson(
    client,
    ManagerApiEndpoints.token,
    body: <String, dynamic>{
      'username': managerUsername,
      'password': managerPassword,
    },
  );

  expect(loginResponse.statusCode, 200);

  final Map<String, dynamic> loginBody = decodeObject(loginResponse);
  final String accessToken = (loginBody['access'] as String?)?.trim() ?? '';
  final String refreshToken = (loginBody['refresh'] as String?)?.trim() ?? '';

  expect(accessToken, isNotEmpty);
  expect(refreshToken, isNotEmpty);

  return ManagerSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
  );
}

Future<CreatedGroup> createTemporaryGroup(
  http.Client client,
  ManagerSession session,
) async {
  final List<int> groupContentKeyBytes = await EyesOnlyCrypto.generateKey();
  final ({String ciphertext, String nonce}) encryptedName =
      await EyesOnlyCrypto.symmetricEncrypt(
    utf8.encode('integration-group-${uniqueSuffix()}'),
    groupContentKeyBytes,
  );

  final http.Response createGroupResponse = await postJson(
    client,
    ManagerApiEndpoints.createGroup,
    headers: jsonHeaders(authorization: 'Bearer ${session.accessToken}'),
    body: <String, dynamic>{
      'encrypted_name': encryptedName.ciphertext,
      'name_nonce': encryptedName.nonce,
      'crypto_version': 1,
      'encryption_algorithm': EyesOnlyCrypto.symmetricAlgorithm,
    },
  );

  expect(createGroupResponse.statusCode, 201);

  final Map<String, dynamic> createBody = decodeObject(createGroupResponse);
  final String groupId = (createBody['uuid'] as String?)?.trim() ?? '';
  expect(groupId, isNotEmpty);

  return CreatedGroup(
    groupId: groupId,
    contentKeyBytes: groupContentKeyBytes,
  );
}

Future<void> updateTemporaryGroup(
  http.Client client,
  ManagerSession session, {
  required String groupId,
  required List<int> contentKeyBytes,
}) async {
  final ({String ciphertext, String nonce}) updatedName =
      await EyesOnlyCrypto.symmetricEncrypt(
    utf8.encode('integration-group-updated-${uniqueSuffix()}'),
    contentKeyBytes,
  );

  final http.Response updateGroupResponse = await client.patch(
    apiUri(ManagerApiEndpoints.updateGroup),
    headers: jsonHeaders(authorization: 'Bearer ${session.accessToken}'),
    body: jsonEncode(<String, dynamic>{
      'group': groupId,
      'encrypted_name': updatedName.ciphertext,
      'name_nonce': updatedName.nonce,
      'crypto_version': 1,
      'encryption_algorithm': EyesOnlyCrypto.symmetricAlgorithm,
    }),
  );

  expect(updateGroupResponse.statusCode, 200);

  final Map<String, dynamic> updateBody = decodeObject(updateGroupResponse);
  expect(updateBody['uuid'], groupId);
}

Future<void> deleteGroup(
  http.Client client,
  ManagerSession session,
  String groupId,
) async {
  final http.Request deleteRequest = http.Request(
    'DELETE',
    apiUri(ManagerApiEndpoints.deleteGroup),
  );
  deleteRequest.headers.addAll(
    jsonHeaders(authorization: 'Bearer ${session.accessToken}'),
  );
  deleteRequest.body = jsonEncode(<String, dynamic>{'group': groupId});

  final http.StreamedResponse streamedResponse = await client.send(deleteRequest);
  final http.Response response = await http.Response.fromStream(streamedResponse);
  expect(response.statusCode, anyOf(200, 204));
}

Future<void> tryDeleteGroup(
  http.Client client,
  ManagerSession session,
  String groupId,
) async {
  try {
    await deleteGroup(client, session, groupId);
  } catch (_) {}
}

Future<List<Map<String, dynamic>>> getManagerGroups(
  http.Client client,
  ManagerSession session,
) async {
  final http.Response response = await client.get(
    apiUri(ManagerApiEndpoints.managerGroups),
    headers: jsonHeaders(authorization: 'Bearer ${session.accessToken}'),
  );
  expect(response.statusCode, 200);
  return decodeList(response);
}

Future<List<Map<String, dynamic>>> getMainManagerGroups(
  http.Client client,
  ManagerSession session,
) async {
  final http.Response response = await client.get(
    apiUri(ManagerApiEndpoints.mainManagerGroups),
    headers: jsonHeaders(authorization: 'Bearer ${session.accessToken}'),
  );
  expect(response.statusCode, 200);
  return decodeList(response);
}

Future<List<Map<String, dynamic>>> getGroupDevices(
  http.Client client,
  ManagerSession session,
  String groupId,
) async {
  final http.Response response = await client.get(
    apiUri(
      ManagerApiEndpoints.mainManagerGroupDevices,
      queryParameters: <String, String>{'group': groupId},
    ),
    headers: jsonHeaders(authorization: 'Bearer ${session.accessToken}'),
  );
  expect(response.statusCode, 200);
  return decodeList(response);
}

Future<DeviceKeyMaterial> generateDeviceKeyMaterial({required String label}) async {
  final KeyPair keyPair = await X25519().newKeyPair();
  final PublicKey rawPublicKey = await keyPair.extractPublicKey();
  if (rawPublicKey is! SimplePublicKey) {
    throw TestFailure('Expected a SimplePublicKey for generated test device.');
  }

  final KeyPairData keyPairData = await keyPair.extract();
  if (keyPairData is! SimpleKeyPairData) {
    throw TestFailure('Expected a SimpleKeyPairData for generated test device.');
  }

  final List<int> privateKeyBytes = keyPairData.bytes;
  final String publicKeyB64 = base64Encode(rawPublicKey.bytes);
  final String privateKeyB64 = base64Encode(privateKeyBytes);

  return DeviceKeyMaterial(
    deviceIdentifier: 'test-$label-${uniqueSuffix()}',
    publicKeyB64: publicKeyB64,
    privateKeyB64: privateKeyB64,
    publicKeyFingerprint: await EyesOnlyCrypto.publicKeyFingerprint(publicKeyB64),
  );
}

Future<void> registerDevice(
  http.Client client,
  ManagerSession session,
  DeviceKeyMaterial device,
) async {
  final http.Response response = await postJson(
    client,
    ManagerApiEndpoints.registerDevice,
    headers: jsonHeaders(authorization: 'Bearer ${session.accessToken}'),
    body: <String, dynamic>{
      'device_identifier': device.deviceIdentifier,
      'public_key': device.publicKeyB64,
      'public_key_algorithm': defaultPublicKeyAlgorithm,
    },
  );

  expect(response.statusCode, anyOf(200, 201));
}

Future<void> addDeviceToGroup(
  http.Client client,
  ManagerSession session,
  DeviceKeyMaterial device,
  String groupId,
) async {
  final http.Response response = await postJson(
    client,
    ManagerApiEndpoints.addDeviceToGroup,
    headers: jsonHeaders(authorization: 'Bearer ${session.accessToken}'),
    body: <String, dynamic>{
      'device_identifier': device.deviceIdentifier,
      'encrypted_member_name': base64Encode(
        utf8.encode('member:${device.deviceIdentifier}'),
      ),
      'group': groupId,
    },
  );

  expect(response.statusCode, anyOf(200, 201));
}

Future<void> removeDeviceFromGroup(
  http.Client client,
  ManagerSession session,
  DeviceKeyMaterial device,
  String groupId,
) async {
  final http.Response response = await postJson(
    client,
    ManagerApiEndpoints.removeDeviceFromGroup,
    headers: jsonHeaders(authorization: 'Bearer ${session.accessToken}'),
    body: <String, dynamic>{
      'device_identifier': device.deviceIdentifier,
      'group': groupId,
    },
  );

  expect(response.statusCode, 204);
}

Future<void> createGroupKeyEnvelope(
  http.Client client,
  ManagerSession session, {
  required DeviceKeyMaterial device,
  required CreatedGroup group,
  String scope = 'group_shared',
}) async {
  final String encryptedGroupKey = await EyesOnlyCrypto.wrapForPublicKey(
    group.contentKeyBytes,
    device.publicKeyB64,
    groupKeyEncryptionHkdfInfo,
  );

  final http.Response response = await postJson(
    client,
    ManagerApiEndpoints.createGroupKeyEnvelope,
    headers: jsonHeaders(authorization: 'Bearer ${session.accessToken}'),
    body: <String, dynamic>{
      'group': group.groupId,
      'scope': scope,
      'key_envelopes': <Map<String, dynamic>>[
        <String, dynamic>{
          'recipient_device_identifier': device.deviceIdentifier,
          'key_wrap_algorithm': EyesOnlyCrypto.asymmetricAlgorithm,
          'recipient_key_fingerprint': device.publicKeyFingerprint,
          'encrypted_group_key': encryptedGroupKey,
        },
      ],
    },
  );

  expect(response.statusCode, anyOf(200, 201));
  expect(decodeObject(response), isNotEmpty);
}

Future<DeviceSession> authenticateDevice(
  http.Client client,
  DeviceKeyMaterial device,
) async {
  final http.Response challengeResponse = await postJson(
    client,
    DeviceApiEndpoints.deviceAuthChallenge,
    body: <String, dynamic>{
      'device_identifier': device.deviceIdentifier,
    },
  );

  expect(challengeResponse.statusCode, 201);

  final Map<String, dynamic> challengeBody = decodeObject(challengeResponse);
  final String decryptedChallenge = await decryptChallenge(
    challengeBody,
    device,
  );

  final http.Response tokenResponse = await postJson(
    client,
    DeviceApiEndpoints.deviceAuthToken,
    body: <String, dynamic>{
      'device_identifier': device.deviceIdentifier,
      'challenge': decryptedChallenge,
    },
  );

  expect(tokenResponse.statusCode, 201);

  final Map<String, dynamic> tokenBody = decodeObject(tokenResponse);
  final String accessToken = (tokenBody['access_token'] as String?)?.trim() ?? '';
  final String tokenType = (tokenBody['token_type'] as String?)?.trim() ?? 'Bearer';

  expect(accessToken, isNotEmpty);

  return DeviceSession(
    keyMaterial: device,
    accessToken: accessToken,
    tokenType: tokenType,
  );
}

Future<String> decryptChallenge(
  Map<String, dynamic> challengeBody,
  DeviceKeyMaterial device,
) async {
  final dynamic encryptedChallengeRaw = challengeBody['encrypted_challenge'];
  if (encryptedChallengeRaw is! Map<String, dynamic>) {
    throw TestFailure('Device auth challenge did not contain encrypted_challenge.');
  }

  final String ciphertextB64 =
      (encryptedChallengeRaw['ciphertext'] as String?)?.trim() ?? '';
  final String nonceB64 =
      (encryptedChallengeRaw['nonce'] as String?)?.trim() ?? '';
  final String ephemeralPublicKeyB64 =
      (encryptedChallengeRaw['ephemeral_public_key'] as String?)?.trim() ?? '';
  final String algorithm =
      (encryptedChallengeRaw['algorithm'] as String?)?.trim() ?? '';

  expect(ciphertextB64, isNotEmpty);
  expect(nonceB64, isNotEmpty);
  expect(ephemeralPublicKeyB64, isNotEmpty);
  expect(allowedDeviceChallengeAlgorithms, contains(algorithm));

  final List<int> privateKeyBytes = base64Decode(device.privateKeyB64);
  final List<int> publicKeyBytes = base64Decode(device.publicKeyB64);
  final List<int> ephemeralPublicKeyBytes = base64Decode(ephemeralPublicKeyB64);

  final SecretKey sharedSecret = await X25519().sharedSecretKey(
    keyPair: SimpleKeyPairData(
      privateKeyBytes,
      publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    ),
    remotePublicKey: SimplePublicKey(
      ephemeralPublicKeyBytes,
      type: KeyPairType.x25519,
    ),
  );

  final SecretKey hkdfKey = await Hkdf(
    hmac: Hmac.sha256(),
    outputLength: 32,
  ).deriveKey(
    secretKey: sharedSecret,
    info: utf8.encode(deviceAuthHkdfInfo),
  );

  final List<int> ciphertextWithMac = base64Decode(ciphertextB64);
  const int macLength = 16;
  final SecretBox secretBox = SecretBox(
    ciphertextWithMac.sublist(0, ciphertextWithMac.length - macLength),
    nonce: base64Decode(nonceB64),
    mac: Mac(ciphertextWithMac.sublist(ciphertextWithMac.length - macLength)),
  );

  final List<int> cleartext = await Xchacha20.poly1305Aead().decrypt(
    secretBox,
    secretKey: hkdfKey,
  );
  return utf8.decode(cleartext);
}

Future<List<Map<String, dynamic>>> getDeviceGroups(
  http.Client client,
  DeviceSession session,
) async {
  final http.Response response = await client.get(
    apiUri(DeviceApiEndpoints.deviceGroups),
    headers: deviceJsonHeaders(session),
  );
  expect(response.statusCode, 200);
  return decodeList(response);
}

Future<List<Map<String, dynamic>>> getDeviceGroupKeyEnvelopes(
  http.Client client,
  DeviceSession session,
  List<String> groupIds,
) async {
  final http.Response response = await postJson(
    client,
    DeviceApiEndpoints.deviceGroupKeyEnvelope,
    headers: deviceJsonHeaders(session),
    body: <String, dynamic>{'groups': groupIds},
  );
  expect(response.statusCode, 200);
  return decodeList(response);
}

Future<Map<String, dynamic>> getEncryptedImages(
  http.Client client,
  DeviceSession session,
) async {
  final http.Response response = await client.get(
    apiUri(
      DeviceApiEndpoints.deviceListEncryptedImages,
      queryParameters: const <String, String>{'limit': '10'},
    ),
    headers: deviceJsonHeaders(session),
  );
  expect(response.statusCode, 200);
  return decodeObject(response);
}

Future<void> deleteEncryptedImage(
  http.Client client,
  DeviceSession session, {
  required String groupId,
  required String imageUuid,
}) async {
  final http.Request request = http.Request(
    'DELETE',
    apiUri(DeviceApiEndpoints.deleteEncryptedImage),
  );
  request.headers.addAll(deviceJsonHeaders(session));
  request.body = jsonEncode(<String, dynamic>{
    'group': groupId,
    'image_uuid': imageUuid,
  });

  final http.StreamedResponse streamedResponse = await client.send(request);
  final http.Response response = await http.Response.fromStream(streamedResponse);
  expect(response.statusCode, anyOf(200, 204));
}

String? findFirstImageUuidForGroup(
  Map<String, dynamic> imageListResponse,
  String groupId,
) {
  final List<dynamic> groups = imageListResponse['groups'] as List<dynamic>? ??
      const <dynamic>[];

  for (final dynamic group in groups) {
    if (group is! Map<String, dynamic>) {
      continue;
    }
    if ((group['group'] as String?)?.trim() != groupId) {
      continue;
    }

    final List<dynamic> days = group['days'] as List<dynamic>? ?? const <dynamic>[];
    for (final dynamic day in days) {
      if (day is! Map<String, dynamic>) {
        continue;
      }
      final List<dynamic> images = day['images'] as List<dynamic>? ?? const <dynamic>[];
      for (final dynamic image in images) {
        if (image is! Map<String, dynamic>) {
          continue;
        }
        final String imageUuid = (image['image_uuid'] as String?)?.trim() ?? '';
        if (imageUuid.isNotEmpty) {
          return imageUuid;
        }
      }
    }
  }

  return null;
}

Future<Uint8List> uploadEncryptedBlob(
  http.Client client,
  ManagerSession session, {
  required String groupId,
  required DeviceKeyMaterial recipient,
}) async {
  final List<int> contentKeyBytes = await EyesOnlyCrypto.generateKey();
  final Uint8List plainBytes = Uint8List.fromList(
    utf8.encode('integration-image-${uniqueSuffix()}'),
  );

  final ({String ciphertext, String nonce}) encryptedPayload =
      await EyesOnlyCrypto.symmetricEncrypt(plainBytes, contentKeyBytes);
  final Uint8List encryptedBlobBytes = Uint8List.fromList(
    base64Decode(encryptedPayload.ciphertext),
  );
  final String encryptedContentKey = await EyesOnlyCrypto.wrapForPublicKey(
    contentKeyBytes,
    recipient.publicKeyB64,
    mediaContentKeyEncryptionHkdfInfo,
  );

  final http.MultipartRequest request = http.MultipartRequest(
    'POST',
    apiUri(ManagerApiEndpoints.managerUploadEncryptedBlob),
  );
  request.headers['Authorization'] = 'Bearer ${session.accessToken}';
  request.fields['group'] = groupId;
  request.fields['payload_nonce'] = encryptedPayload.nonce;
  request.fields['crypto_version'] = '1';
  request.fields['encryption_algorithm'] = EyesOnlyCrypto.symmetricAlgorithm;
  request.fields['recipient_envelopes'] = jsonEncode(
    <Map<String, dynamic>>[
      <String, dynamic>{
        'recipient_device_identifier': recipient.deviceIdentifier,
        'key_wrap_algorithm': EyesOnlyCrypto.asymmetricAlgorithm,
        'recipient_key_fingerprint': recipient.publicKeyFingerprint,
        'encrypted_content_key': encryptedContentKey,
      },
    ],
  );
  request.files.add(
    http.MultipartFile.fromBytes(
      'encrypted_blob',
      encryptedBlobBytes,
      filename: 'integration.bin',
    ),
  );

  final http.StreamedResponse streamedResponse = await client.send(request);
  final http.Response response = await http.Response.fromStream(streamedResponse);
  expect(response.statusCode, 201);
  expect(decodeObject(response)['group'], groupId);
  return encryptedBlobBytes;
}

Future<T> pollUntil<T>(
  Future<T?> Function() attempt, {
  required String description,
  int maxAttempts = 10,
  Duration delay = const Duration(milliseconds: 250),
}) async {
  for (int attemptIndex = 0; attemptIndex < maxAttempts; attemptIndex += 1) {
    final T? value = await attempt();
    if (value != null) {
      return value;
    }
    if (attemptIndex < maxAttempts - 1) {
      await Future<void>.delayed(delay);
    }
  }

  throw TestFailure('Timed out waiting for $description.');
}

String uniqueSuffix() {
  final Random random = Random.secure();
  return '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 32)}';
}