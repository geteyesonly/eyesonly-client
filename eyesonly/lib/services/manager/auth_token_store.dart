import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokenStore {
  AuthTokenStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _accessTokenKey = 'manager_auth_access_token';
  static const String _refreshTokenKey = 'manager_auth_refresh_token';

  final FlutterSecureStorage _secureStorage;

  Future<String?> readAccessToken() {
    return _secureStorage.read(key: _accessTokenKey);
  }

  Future<String?> readRefreshToken() {
    return _secureStorage.read(key: _refreshTokenKey);
  }

  Future<void> saveTokens({required String accessToken, String? refreshToken}) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken == null || refreshToken.isEmpty) {
      await _secureStorage.delete(key: _refreshTokenKey);
      return;
    }
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }
}