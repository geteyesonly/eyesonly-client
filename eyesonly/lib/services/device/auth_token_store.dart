import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceAuthCredentials {
  const DeviceAuthCredentials({
    required this.accessToken,
    required this.tokenType,
    this.expiresAt,
  });

  final String accessToken;
  final String tokenType;
  final DateTime? expiresAt;
}

class DeviceAuthTokenStore {
  DeviceAuthTokenStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _accessTokenKey = 'device_auth_access_token';
  static const String _tokenTypeKey = 'device_auth_token_type';
  static const String _expiresAtKey = 'device_auth_expires_at';

  final FlutterSecureStorage _secureStorage;

  Future<void> saveCredentials(DeviceAuthCredentials credentials) async {
    await _secureStorage.write(
      key: _accessTokenKey,
      value: credentials.accessToken,
    );
    await _secureStorage.write(key: _tokenTypeKey, value: credentials.tokenType);
    if (credentials.expiresAt == null) {
      await _secureStorage.delete(key: _expiresAtKey);
    } else {
      await _secureStorage.write(
        key: _expiresAtKey,
        value: credentials.expiresAt!.toIso8601String(),
      );
    }
  }

  Future<DeviceAuthCredentials?> readCredentials() async {
    final String? accessToken = await _secureStorage.read(key: _accessTokenKey);
    final String? tokenType = await _secureStorage.read(key: _tokenTypeKey);

    if (accessToken == null || accessToken.isEmpty || tokenType == null || tokenType.isEmpty) {
      return null;
    }

    final String? expiresAtRaw = await _secureStorage.read(key: _expiresAtKey);
    return DeviceAuthCredentials(
      accessToken: accessToken,
      tokenType: tokenType,
      expiresAt: expiresAtRaw == null || expiresAtRaw.isEmpty
          ? null
          : DateTime.tryParse(expiresAtRaw),
    );
  }

  Future<void> clearCredentials() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _tokenTypeKey);
    await _secureStorage.delete(key: _expiresAtKey);
  }
}