import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../api_exception.dart';
import '../api_service_support.dart';
import 'group_content_key_store.dart';
import 'api_endpoints.dart';
import 'auth_token_store.dart';

class MainManagerGroupDevice {
  const MainManagerGroupDevice({
    required this.deviceIdentifier,
    required this.publicKey,
    required this.publicKeyFingerprint,
    this.encryptedMemberName,
    this.publicKeyAlgorithm,
    this.createdAt,
  });

  final String deviceIdentifier;
  final String? encryptedMemberName;
  final String publicKey;
  final String publicKeyFingerprint;
  final String? publicKeyAlgorithm;
  final DateTime? createdAt;

  factory MainManagerGroupDevice.fromJson(Map<String, dynamic> json) {
    final String? createdAtRaw = (json['created_at'] as String?)?.trim();
    return MainManagerGroupDevice(
      deviceIdentifier: (json['device_identifier'] as String?)?.trim() ?? '',
      encryptedMemberName: (json['encrypted_member_name'] as String?)?.trim(),
      publicKey: (json['public_key'] as String?)?.trim() ?? '',
      publicKeyFingerprint:
          (json['public_key_fingerprint'] as String?)?.trim() ?? '',
      publicKeyAlgorithm: (json['public_key_algorithm'] as String?)?.trim(),
      createdAt: createdAtRaw != null && createdAtRaw.isNotEmpty
          ? DateTime.tryParse(createdAtRaw)
          : null,
    );
  }
}

class UploadEncryptedBlobRequest {
  const UploadEncryptedBlobRequest({
    required this.groupId,
    required this.encryptedBlobBytes,
    required this.payloadNonce,
    required this.recipientEnvelopes,
    this.encryptedCaption,
    this.cryptoVersion = 1,
    this.encryptionAlgorithm,
    this.expiresAt,
    this.clientCiphertextHashSha256,
  });

  final String groupId;
  final Uint8List encryptedBlobBytes;
  final String payloadNonce;
  final List<Map<String, dynamic>> recipientEnvelopes;
  final String? encryptedCaption;
  final int cryptoVersion;
  final String? encryptionAlgorithm;
  final DateTime? expiresAt;
  final String? clientCiphertextHashSha256;
}

class UploadEncryptedBlobResponse {
  const UploadEncryptedBlobResponse({
    required this.imageId,
    required this.groupId,
    required this.recipientCount,
    required this.ciphertextHashSha256,
    required this.createdAt,
    this.encryptedCaption,
    this.expiresAt,
  });

  final int imageId;
  final String groupId;
  final int recipientCount;
  final String ciphertextHashSha256;
  final DateTime? createdAt;
  final String? encryptedCaption;
  final DateTime? expiresAt;

  factory UploadEncryptedBlobResponse.fromJson(Map<String, dynamic> json) {
    final String? createdAtRaw = (json['created_at'] as String?)?.trim();
    final String? expiresAtRaw = (json['expires_at'] as String?)?.trim();
    return UploadEncryptedBlobResponse(
      imageId: (json['image_id'] as num?)?.toInt() ?? 0,
      groupId: (json['group'] as String?)?.trim() ?? '',
      recipientCount: (json['recipient_count'] as num?)?.toInt() ?? 0,
      ciphertextHashSha256:
          (json['ciphertext_hash_sha256'] as String?)?.trim() ?? '',
      createdAt: createdAtRaw != null && createdAtRaw.isNotEmpty
          ? DateTime.tryParse(createdAtRaw)
          : null,
      encryptedCaption: (json['encrypted_caption'] as String?)?.trim(),
      expiresAt: expiresAtRaw != null && expiresAtRaw.isNotEmpty
          ? DateTime.tryParse(expiresAtRaw)
          : null,
    );
  }
}

class ManagerApiService {
  ManagerApiService({
    required this.baseUrl,
    http.Client? client,
    AuthTokenStore? tokenStore,
  }) : _client = client ?? http.Client(),
       _tokenStore = tokenStore ?? AuthTokenStore();

  final String baseUrl;
  final http.Client _client;
  final AuthTokenStore _tokenStore;
  static const String _sessionExpiredMessage =
      'Your manager session has expired. Please log in again.';

  String? _accessToken;
  String? _refreshToken;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  Future<void> hydrateTokens() async {
    _accessToken = await _tokenStore.readAccessToken();
    _refreshToken = await _tokenStore.readRefreshToken();
  }

  Future<void> clearStoredTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await _tokenStore.clearTokens();
  }

  Future<void> _refreshAccessToken() async {
    final String? refreshToken =
        _refreshToken ?? await _tokenStore.readRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      await clearStoredTokens();
      throw ApiException(_sessionExpiredMessage, statusCode: 401);
    }

    final http.Response response = await _client.post(
      _uri(ManagerApiEndpoints.refreshToken),
      headers: _headers(includeAuth: false),
      body: jsonEncode(<String, String>{'refresh': refreshToken}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      await clearStoredTokens();
      throw ApiException(
        _sessionExpiredMessage,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final Map<String, dynamic> data = _decodeObject(response.body);
    final String accessToken = (data['access'] as String?)?.trim() ?? '';
    if (accessToken.isEmpty) {
      await clearStoredTokens();
      throw ApiException(_sessionExpiredMessage, responseBody: response.body);
    }

    final String nextRefreshToken =
        (data['refresh'] as String?)?.trim().isNotEmpty == true
        ? (data['refresh'] as String).trim()
        : refreshToken;

    _accessToken = accessToken;
    _refreshToken = nextRefreshToken;
    await _tokenStore.saveTokens(
      accessToken: accessToken,
      refreshToken: nextRefreshToken,
    );
  }

  bool _shouldRefresh(http.Response response) {
    if (response.statusCode != 401) {
      return false;
    }

    final dynamic decoded = _tryDecodeJson(response.body);
    if (decoded is Map<String, dynamic>) {
      final String? code = decoded['code'] as String?;
      if (code == 'token_not_valid') {
        return true;
      }
      final String? detail = decoded['detail'] as String?;
      if (detail != null && detail.isNotEmpty) {
        return true;
      }
    }

    return true;
  }

  Future<http.Response> _sendWithRefreshRetry(
    Future<http.Response> Function() request,
  ) async {
    http.Response response = await request();
    if (_shouldRefresh(response)) {
      await _refreshAccessToken();
      response = await request();
    }
    return response;
  }

  Uri _uri(String path) {
    return ApiServiceSupport.buildUri(baseUrl: baseUrl, path: path);
  }

  Map<String, String> _headers({bool includeAuth = true}) {
    return ApiServiceSupport.jsonHeaders(
      authorization:
          includeAuth && _accessToken != null ? 'Bearer $_accessToken' : null,
    );
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    String endpoint = ManagerApiEndpoints.token,
  }) async {
    final http.Response response = await _client.post(
      _uri(endpoint),
      headers: _headers(includeAuth: false),
      body: jsonEncode(<String, String>{
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _buildLoginErrorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final Map<String, dynamic> data = _decodeObject(response.body);

    final dynamic token = data['access'];
    if (token is String && token.isNotEmpty) {
      _accessToken = token;
      final dynamic refresh = data['refresh'];
      final String? refreshToken = refresh is String && refresh.isNotEmpty
          ? refresh
          : null;
      _refreshToken = refreshToken;
      await _tokenStore.saveTokens(
        accessToken: token,
        refreshToken: refreshToken,
      );
      return data;
    }

    throw ApiException(
      'Login succeeded but no access token was returned by the server.',
      statusCode: response.statusCode,
      responseBody: response.body,
    );
  }

  Future<void> logout({String endpoint = ManagerApiEndpoints.tokenLogout}) async {
    final String? refreshToken =
        _refreshToken ?? await _tokenStore.readRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      return;
    }

    final http.Response response = await _client.post(
      _uri(endpoint),
      headers: _headers(includeAuth: false),
      body: jsonEncode(<String, String>{'refresh': refreshToken}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _buildLogoutErrorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
  }

  Future<void> registerDevice({
    required String deviceIdentifier,
    required String publicKey,
    required String publicKeyAlgorithm,
    int? ownerUser,
    String endpoint = ManagerApiEndpoints.registerDevice,
  }) async {
    final http.Response response = await _sendWithRefreshRetry(
      () => _client.post(
        _uri(endpoint),
        headers: _headers(),
        body: jsonEncode(<String, dynamic>{
          'device_identifier': deviceIdentifier,
          'public_key': publicKey,
          'public_key_algorithm': publicKeyAlgorithm,
          'owner_user': ?ownerUser,
        }),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _buildDeviceRegistrationErrorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
  }

  Future<Map<String, dynamic>> createGroup({
    required String encryptedName,
    required String nameNonce,
    int? cryptoVersion,
    String? encryptionAlgorithm,
    String endpoint = ManagerApiEndpoints.createGroup,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'encrypted_name': encryptedName,
      'name_nonce': nameNonce,
      'crypto_version': ?cryptoVersion,
      if (encryptionAlgorithm != null && encryptionAlgorithm.trim().isNotEmpty)
        'encryption_algorithm': encryptionAlgorithm.trim(),
    };

    final http.Response response = await _sendWithRefreshRetry(
      () => _client.post(
        _uri(endpoint),
        headers: _headers(),
        body: jsonEncode(payload),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _buildCreateGroupErrorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    return _decodeObject(response.body);
  }

  Future<Map<String, dynamic>> updateGroup({
    required String groupId,
    String? encryptedName,
    int? cryptoVersion,
    String? encryptionAlgorithm,
    String? nameNonce,
    String endpoint = ManagerApiEndpoints.updateGroup,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'group': groupId,
      if (encryptedName != null && encryptedName.trim().isNotEmpty)
        'encrypted_name': encryptedName.trim(),
      'crypto_version': ?cryptoVersion,
      if (encryptionAlgorithm != null && encryptionAlgorithm.trim().isNotEmpty)
        'encryption_algorithm': encryptionAlgorithm.trim(),
      if (nameNonce != null && nameNonce.trim().isNotEmpty)
        'name_nonce': nameNonce.trim(),
    };

    final http.Response response = await _sendWithRefreshRetry(
      () => _client.patch(
        _uri(endpoint),
        headers: _headers(),
        body: jsonEncode(payload),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _buildUpdateGroupErrorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    return _decodeObject(response.body);
  }

  Future<Map<String, dynamic>> createGroupKeyEnvelope({
    required String groupId,
    required List<Map<String, dynamic>> keyEnvelopes,
    String scope = groupKeyScopeGroupShared,
    String endpoint = ManagerApiEndpoints.createGroupKeyEnvelope,
  }) async {
    final http.Response response = await _sendWithRefreshRetry(
      () => _client.post(
        _uri(endpoint),
        headers: _headers(),
        body: jsonEncode(<String, dynamic>{
          'group': groupId,
          'scope': scope,
          'key_envelopes': keyEnvelopes,
        }),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _buildCreateGroupKeyEnvelopeErrorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    return _decodeObject(response.body);
  }

  Future<Map<String, dynamic>> notifyGroup({
    required String groupId,
    required String encryptedPayload,
    required String nonce,
    int cryptoVersion = 1,
    String encryptionAlgorithm = 'xchacha20poly1305',
    String endpoint = ManagerApiEndpoints.managerNotifyGroup,
  }) async {
    final http.Response response = await _sendWithRefreshRetry(
      () => _client.post(
        _uri(endpoint),
        headers: _headers(),
        body: jsonEncode(<String, dynamic>{
          'group': groupId,
          'encrypted_payload': encryptedPayload,
          'nonce': nonce,
          'crypto_version': cryptoVersion,
          'encryption_algorithm': encryptionAlgorithm,
        }),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _buildNotifyGroupErrorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    return _decodeObject(response.body);
  }

  Future<void> deleteGroup({
    required String groupId,
    String endpoint = ManagerApiEndpoints.deleteGroup,
  }) async {
    final http.Response response = await _sendWithRefreshRetry(() async {
      final http.Request request = http.Request('DELETE', _uri(endpoint));
      request.headers.addAll(_headers());
      request.body = jsonEncode(<String, String>{'group': groupId});
      final http.StreamedResponse streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _buildDeleteGroupErrorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
  }

  /// Fetches the groups where the current manager is the main manager.
  /// Returns raw MainManagerGroup objects from the API.
  /// Group names are encrypted (`encrypted_name` + `name_nonce`) and must be
  /// decrypted by the caller when a matching content key is available.
  Future<List<Map<String, dynamic>>> getManagerGroups() async {
    final http.Response response = await _sendWithRefreshRetry(
      () => _client.get(
        _uri(ManagerApiEndpoints.managerGroups),
        headers: _headers(),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to fetch manager groups',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }
    throw ApiException(
      'Expected a JSON list response for manager groups',
      responseBody: response.body,
    );
  }

  Future<List<MainManagerGroupDevice>> getManagerDevices() async {
    final http.Response response = await _sendWithRefreshRetry(
      () => _client.get(
        _uri(ManagerApiEndpoints.managerDevices),
        headers: _headers(),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to fetch manager devices',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(MainManagerGroupDevice.fromJson)
          .toList();
    }
    throw ApiException(
      'Expected a JSON list response for manager devices',
      responseBody: response.body,
    );
  }

  Future<List<Map<String, dynamic>>> getMainManagerGroups() async {
    final http.Response response = await _sendWithRefreshRetry(
      () => _client.get(
        _uri(ManagerApiEndpoints.mainManagerGroups),
        headers: _headers(),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to fetch main manager groups',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is List) {
      // Each item should be a MainManagerGroup object from api.yaml.
      return decoded.whereType<Map<String, dynamic>>().toList();
    }
    throw ApiException(
      'Expected a JSON list response for main manager groups',
      responseBody: response.body,
    );
  }

  Future<List<MainManagerGroupDevice>> getManagerGroupDevices({
    required String groupId,
  }) async {
    final Uri uri = _uri(ManagerApiEndpoints.managerGroupDevices).replace(
      queryParameters: <String, String>{'group': groupId},
    );

    final http.Response response = await _sendWithRefreshRetry(
      () => _client.get(
        uri,
        headers: _headers(),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to fetch manager-owned group devices',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(MainManagerGroupDevice.fromJson)
          .toList();
    }

    throw ApiException(
      'Expected a JSON list response for manager-owned group devices',
      responseBody: response.body,
    );
  }

  Future<List<MainManagerGroupDevice>> getMainManagerGroupDevices({
    required String groupId,
  }) async {
    final Uri uri = _uri(ManagerApiEndpoints.mainManagerGroupDevices).replace(
      queryParameters: <String, String>{'group': groupId},
    );

    final http.Response response = await _sendWithRefreshRetry(
      () => _client.get(
        uri,
        headers: _headers(),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to fetch group devices',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(MainManagerGroupDevice.fromJson)
          .toList();
    }

    throw ApiException(
      'Expected a JSON list response for group devices',
      responseBody: response.body,
    );
  }

  Future<void> addDeviceToGroup({
    required String deviceIdentifier,
    required String groupId,
    required String encryptedMemberName,
    bool isManager = false,
    String endpoint = ManagerApiEndpoints.addDeviceToGroup,
  }) async {
    final http.Response response = await _sendWithRefreshRetry(
      () => _client.post(
        _uri(endpoint),
        headers: _headers(),
        body: jsonEncode(<String, dynamic>{
          'device_identifier': deviceIdentifier,
          'group': groupId,
          'encrypted_member_name': encryptedMemberName,
          'is_manager': isManager,
        }),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _buildAddToGroupErrorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
  }

  Future<void> removeDeviceFromGroup({
    required String deviceIdentifier,
    required String groupId,
    String endpoint = ManagerApiEndpoints.removeDeviceFromGroup,
  }) async {
    final http.Response response = await _sendWithRefreshRetry(
      () => _client.post(
        _uri(endpoint),
        headers: _headers(),
        body: jsonEncode(<String, String>{
          'device_identifier': deviceIdentifier,
          'group': groupId,
        }),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _buildRemoveFromGroupErrorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
  }

  Future<void> registerDeviceFcm({
    required String registrationId,
    required String deviceType,
    String endpoint = ManagerApiEndpoints.deviceFcm,
  }) async {
    final http.Response response = await _sendWithRefreshRetry(
      () => _client.post(
        _uri(endpoint),
        headers: _headers(),
        body: jsonEncode(<String, dynamic>{
          'registration_id': registrationId,
          'type': deviceType,
        }),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _buildRegisterDeviceFcmErrorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
  }

  Future<void> deregisterDeviceFcm({
    String endpoint = ManagerApiEndpoints.deviceFcmDeregister,
  }) async {
    final http.Response response = await _sendWithRefreshRetry(
      () => _client.delete(
        _uri(endpoint),
        headers: _headers(),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _buildDeregisterDeviceFcmErrorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
  }

  Future<UploadEncryptedBlobResponse> uploadEncryptedBlob({
    required UploadEncryptedBlobRequest request,
    String endpoint = ManagerApiEndpoints.managerUploadEncryptedBlob,
  }) async {
    final http.Response response = await _sendWithRefreshRetry(() async {
      final http.MultipartRequest multipartRequest = http.MultipartRequest(
        'POST',
        _uri(endpoint),
      );
      final String? token = _accessToken;
      if (token != null && token.isNotEmpty) {
        multipartRequest.headers['Authorization'] = 'Bearer $token';
      }

      multipartRequest.fields['group'] = request.groupId;
      multipartRequest.fields['payload_nonce'] = request.payloadNonce;
      multipartRequest.fields['crypto_version'] =
          request.cryptoVersion.toString();
      multipartRequest.fields['encryption_algorithm'] =
          request.encryptionAlgorithm?.trim().isNotEmpty == true
          ? request.encryptionAlgorithm!.trim()
          : 'xchacha20poly1305';
      multipartRequest.fields['recipient_envelopes'] = jsonEncode(
        request.recipientEnvelopes,
      );

      final String? encryptedCaption = request.encryptedCaption?.trim();
      if (encryptedCaption != null && encryptedCaption.isNotEmpty) {
        multipartRequest.fields['encrypted_caption'] = encryptedCaption;
      }

      if (request.expiresAt != null) {
        multipartRequest.fields['expires_at'] = request.expiresAt!.toUtc().toIso8601String();
      }

      final String? ciphertextHash = request.clientCiphertextHashSha256?.trim();
      if (ciphertextHash != null && ciphertextHash.isNotEmpty) {
        multipartRequest.fields['client_ciphertext_hash_sha256'] = ciphertextHash;
      }

      multipartRequest.files.add(
        http.MultipartFile.fromBytes(
          'encrypted_blob',
          request.encryptedBlobBytes,
          filename: 'encrypted_blob.bin',
        ),
      );

      final http.StreamedResponse streamed = await _client.send(multipartRequest);
      return http.Response.fromStream(streamed);
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _buildUploadEncryptedBlobErrorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    return UploadEncryptedBlobResponse.fromJson(_decodeObject(response.body));
  }

  Map<String, dynamic> _decodeObject(String body) {
    return ApiServiceSupport.decodeObject(body);
  }

  String _buildLoginErrorMessage(http.Response response) {
    final dynamic decoded = _tryDecodeJson(response.body);

    if (response.statusCode == 400 && decoded is Map<String, dynamic>) {
      final String? usernameError = _extractFieldError(decoded['username']);
      final String? passwordError = _extractFieldError(decoded['password']);
      final String? detailError = _extractFieldError(decoded['detail']);
      final String? nonFieldError = _extractFieldError(
        decoded['non_field_errors'],
      );

      final List<String> parts = <String>[
        if (usernameError != null) 'Username: $usernameError',
        if (passwordError != null) 'Password: $passwordError',
        ?nonFieldError,
        ?detailError,
      ];

      if (parts.isNotEmpty) {
        return parts.join(' ');
      }
    }

    if (response.statusCode == 401) {
      if (decoded is Map<String, dynamic>) {
        final String? detailError = _extractFieldError(decoded['detail']);
        final String? nonFieldError = _extractFieldError(
          decoded['non_field_errors'],
        );
        if (detailError != null) {
          return detailError;
        }
        if (nonFieldError != null) {
          return nonFieldError;
        }
      }
      return 'Invalid username or password.';
    }

    if (response.statusCode >= 500) {
      return 'Server error while logging in. Please try again in a moment.';
    }

    final String? genericMessage = _extractFieldError(decoded);
    if (genericMessage != null) {
      return genericMessage;
    }

    return 'Login request failed (${response.statusCode}).';
  }

  String _buildLogoutErrorMessage(http.Response response) {
    final dynamic decoded = _tryDecodeJson(response.body);
    final String? detailError = _extractFieldError(
      decoded is Map<String, dynamic>
          ? decoded['detail'] ?? decoded['non_field_errors'] ?? decoded
          : decoded,
    );

    if (detailError != null) {
      return detailError;
    }

    return 'Logout request failed (${response.statusCode}).';
  }

  String _buildCreateGroupKeyEnvelopeErrorMessage(http.Response response) {
    final dynamic decoded = _tryDecodeJson(response.body);
    final String? detailError = _extractFieldError(
      decoded is Map<String, dynamic>
          ? decoded['detail'] ?? decoded['non_field_errors'] ?? decoded
          : decoded,
    );

    if (detailError != null) {
      return detailError;
    }

    return 'Creating group key envelope failed (${response.statusCode}).';
  }

  String _buildNotifyGroupErrorMessage(http.Response response) {
    final dynamic decoded = _tryDecodeJson(response.body);
    if (decoded is Map<String, dynamic>) {
      final String? detail = decoded['detail'] as String?;
      if (detail != null && detail.trim().isNotEmpty) {
        return detail.trim();
      }
      final Object? nonFieldErrors = decoded['non_field_errors'];
      if (nonFieldErrors is List && nonFieldErrors.isNotEmpty) {
        final String message = nonFieldErrors.first.toString().trim();
        if (message.isNotEmpty) {
          return message;
        }
      }
    }

    return 'Sending group notification failed (${response.statusCode}).';
  }

  String _buildUpdateGroupErrorMessage(http.Response response) {
    final dynamic decoded = _tryDecodeJson(response.body);
    final String? detailError = _extractFieldError(
      decoded is Map<String, dynamic>
          ? decoded['detail'] ?? decoded['non_field_errors'] ?? decoded
          : decoded,
    );

    if (detailError != null) {
      return detailError;
    }

    return 'Updating group failed (${response.statusCode}).';
  }

  String _buildDeleteGroupErrorMessage(http.Response response) {
    final dynamic decoded = _tryDecodeJson(response.body);
    final String? detailError = _extractFieldError(
      decoded is Map<String, dynamic>
          ? decoded['detail'] ?? decoded['non_field_errors'] ?? decoded
          : decoded,
    );

    if (detailError != null) {
      return detailError;
    }

    return 'Deleting group failed (${response.statusCode}).';
  }

  String _buildAddToGroupErrorMessage(http.Response response) {
    final dynamic decoded = _tryDecodeJson(response.body);
    final String? detailError = _extractFieldError(
      decoded is Map<String, dynamic>
          ? decoded['detail'] ?? decoded['non_field_errors'] ?? decoded
          : decoded,
    );

    if (detailError != null) {
      return detailError;
    }

    return 'Adding device to group failed (${response.statusCode}).';
  }

  String _buildRemoveFromGroupErrorMessage(http.Response response) {
    final dynamic decoded = _tryDecodeJson(response.body);
    final String? detailError = _extractFieldError(
      decoded is Map<String, dynamic>
          ? decoded['detail'] ?? decoded['non_field_errors'] ?? decoded
          : decoded,
    );

    if (detailError != null) {
      return detailError;
    }

    return 'Removing device from group failed (${response.statusCode}).';
  }

  String _buildRegisterDeviceFcmErrorMessage(http.Response response) {
    final dynamic decoded = _tryDecodeJson(response.body);
    final String? detailError = _extractFieldError(
      decoded is Map<String, dynamic>
          ? decoded['detail'] ?? decoded['non_field_errors'] ?? decoded
          : decoded,
    );

    if (detailError != null) {
      return detailError;
    }

    return 'Registering push notifications failed (${response.statusCode}).';
  }

  String _buildDeregisterDeviceFcmErrorMessage(http.Response response) {
    final dynamic decoded = _tryDecodeJson(response.body);
    final String? detailError = _extractFieldError(
      decoded is Map<String, dynamic>
          ? decoded['detail'] ?? decoded['non_field_errors'] ?? decoded
          : decoded,
    );

    if (detailError != null) {
      return detailError;
    }

    return 'Disabling push notifications failed (${response.statusCode}).';
  }

  String _buildUploadEncryptedBlobErrorMessage(http.Response response) {
    return _build403QuotaErrorMessage(
      response,
      quotaType: 'images',
      fallbackMessage: 'Uploading encrypted blob failed',
    );
  }

  String _buildDeviceRegistrationErrorMessage(http.Response response) {
    // Override the base implementation to handle quota
    return _build403QuotaErrorMessage(
      response,
      quotaType: 'devices',
      fallbackMessage: 'Device registration failed',
    );
  }

  String _buildCreateGroupErrorMessage(http.Response response) {
    // Override the base implementation to handle quota
    return _build403QuotaErrorMessage(
      response,
      quotaType: 'groups',
      fallbackMessage: 'Creating group failed',
    );
  }

  /// Builds error messages for 403 responses with quota information.
  /// 
  /// Attempts to parse `quota`, `current`, and `maximum` fields from the response.
  /// If found, constructs a user-friendly message. Falls back to `detail` field
  /// or a generic message if quota fields are unavailable.
  String _build403QuotaErrorMessage(
    http.Response response, {
    required String quotaType,
    required String fallbackMessage,
  }) {
    final dynamic decoded = _tryDecodeJson(response.body);

    if (response.statusCode == 403 && decoded is Map<String, dynamic>) {
      final String? quotaKey = (decoded['quota'] as String?)?.trim();
      final int? current = decoded['current'] as int?;
      final int? maximum = decoded['maximum'] as int?;

      // If we have quota details, build a helpful message
      if (quotaKey != null && quotaKey.isNotEmpty && current != null && maximum != null) {
        return '$fallbackMessage: Maximum $quotaType quota reached ($current/$maximum).';
      }
    }

    // Fall back to detail field or generic message
    final String? detailError = _extractFieldError(
      decoded is Map<String, dynamic>
          ? decoded['detail'] ?? decoded['non_field_errors'] ?? decoded
          : decoded,
    );

    if (detailError != null) {
      return detailError;
    }

    return '$fallbackMessage (${response.statusCode}).';
  }

  dynamic _tryDecodeJson(String body) {
    return ApiServiceSupport.tryDecodeJson(body);
  }

  String? _extractFieldError(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is List) {
      final List<String> items = value
          .whereType<String>()
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty)
          .toList();
      if (items.isNotEmpty) {
        return items.join(' ');
      }
    }
    if (value is Map<String, dynamic>) {
      final dynamic detail = value['detail'] ?? value['message'] ?? value['error'];
      return _extractFieldError(detail);
    }
    return null;
  }
}