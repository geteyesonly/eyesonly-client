import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:eyesonly/services/api_exception.dart';
import 'package:eyesonly/services/crypto/eyes_only_crypto.dart';
import 'package:eyesonly/services/device/api_endpoints.dart';
import 'package:eyesonly/services/device/api_service.dart';
import 'package:eyesonly/services/device/auth_token_store.dart';
import 'package:eyesonly/services/device/hkdf_info.dart';
import 'package:eyesonly/services/installation_id_store.dart';
import 'package:eyesonly/services/manager/api_endpoints.dart';
import 'package:eyesonly/services/manager/api_service.dart';
import 'package:eyesonly/services/manager/auth_token_store.dart';

void main() {
  group('ManagerApiService', () {
    test('refreshes access token and retries once after 401', () async {
      final FakeAuthTokenStore tokenStore = FakeAuthTokenStore(
        accessToken: 'stale-access',
        refreshToken: 'refresh-1',
      );
      int createGroupCalls = 0;

      final ManagerApiService service = ManagerApiService(
        baseUrl: 'http://localhost:8080/api',
        tokenStore: tokenStore,
        client: MockClient((http.Request request) async {
          if (request.url.path.endsWith(ManagerApiEndpoints.createGroup)) {
            createGroupCalls += 1;
            if (createGroupCalls == 1) {
              expect(request.headers['authorization'], 'Bearer stale-access');
              return http.Response(
                '{"code":"token_not_valid"}',
                401,
                headers: <String, String>{'content-type': 'application/json'},
              );
            }

            expect(request.headers['authorization'], 'Bearer fresh-access');
            return http.Response(
              '{"uuid":"group-1","encrypted_name":"abc","name_nonce":"nonce"}',
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }

          if (request.url.path.endsWith(ManagerApiEndpoints.refreshToken)) {
            expect(jsonDecode(request.body), <String, dynamic>{'refresh': 'refresh-1'});
            return http.Response(
              '{"access":"fresh-access","refresh":"refresh-2"}',
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }

          fail('Unexpected request: ${request.method} ${request.url}');
        }),
      );

      await service.hydrateTokens();
      final Map<String, dynamic> response = await service.createGroup(
        encryptedName: 'abc',
        nameNonce: 'nonce',
      );

      expect(createGroupCalls, 2);
      expect(response['uuid'], 'group-1');
      expect(tokenStore.savedAccessToken, 'fresh-access');
      expect(tokenStore.savedRefreshToken, 'refresh-2');
    });

    test('clears stored tokens when refresh fails', () async {
      final FakeAuthTokenStore tokenStore = FakeAuthTokenStore(
        accessToken: 'stale-access',
        refreshToken: 'refresh-1',
      );

      final ManagerApiService service = ManagerApiService(
        baseUrl: 'http://localhost:8080/api',
        tokenStore: tokenStore,
        client: MockClient((http.Request request) async {
          if (request.url.path.endsWith(ManagerApiEndpoints.createGroup)) {
            return http.Response(
              '{"detail":"expired"}',
              401,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }

          if (request.url.path.endsWith(ManagerApiEndpoints.refreshToken)) {
            return http.Response(
              '{"detail":"invalid refresh"}',
              401,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }

          fail('Unexpected request: ${request.method} ${request.url}');
        }),
      );

      await service.hydrateTokens();

      await expectLater(
        () => service.createGroup(encryptedName: 'abc', nameNonce: 'nonce'),
        throwsA(isA<ApiException>()),
      );

      expect(tokenStore.clearCalled, isTrue);
      expect(service.accessToken, isNull);
      expect(service.refreshToken, isNull);
    });
  });

  group('DeviceApiService', () {
    test('re-authenticates and retries self status after 401', () async {
      final FakeDeviceAuthTokenStore tokenStore = FakeDeviceAuthTokenStore(
        credentials: DeviceAuthCredentials(
          accessToken: 'stale-device-token',
          tokenType: 'Bearer',
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        ),
      );
      final FixedInstallationIdStore installationIdStore =
          FixedInstallationIdStore('device-123');
      final FakeFlutterSecureStorage secureStorage = FakeFlutterSecureStorage();
      final _DeviceKeyMaterial keyMaterial = await _createDeviceKeyMaterial();
      await secureStorage.write(
        key: 'device_private_key',
        value: keyMaterial.privateKeyB64,
      );
      await secureStorage.write(
        key: 'device_public_key',
        value: keyMaterial.publicKeyB64,
      );

      int statusCalls = 0;
      final DeviceApiService service = DeviceApiService(
        baseUrl: 'http://localhost:8080/api',
        client: MockClient((http.Request request) async {
          if (request.url.path.endsWith(DeviceApiEndpoints.deviceStatus)) {
            statusCalls += 1;
            if (statusCalls == 1) {
              expect(
                request.headers['authorization'],
                'Bearer stale-device-token',
              );
              return http.Response('unauthorized', 401);
            }

            expect(
              request.headers['authorization'],
              'Bearer fresh-device-token',
            );
            expect(request.headers['x-device-identifier'], 'device-123');
            return http.Response(
              '{"device_identifier":"device-123","is_registered":true,"group_names":["A"]}',
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }

          if (request.url.path.endsWith(DeviceApiEndpoints.deviceAuthChallenge)) {
            expect(jsonDecode(request.body), <String, dynamic>{
              'device_identifier': 'device-123',
            });
            final Map<String, dynamic> encryptedChallenge =
                await _buildEncryptedChallenge(
                  publicKeyB64: keyMaterial.publicKeyB64,
                  plaintext: 'challenge-value',
                );
            return http.Response(
              jsonEncode(<String, dynamic>{
                'encrypted_challenge': encryptedChallenge,
              }),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }

          if (request.url.path.endsWith(DeviceApiEndpoints.deviceAuthToken)) {
            expect(jsonDecode(request.body), <String, dynamic>{
              'device_identifier': 'device-123',
              'challenge': 'challenge-value',
            });
            return http.Response(
              jsonEncode(<String, dynamic>{
                'access_token': 'fresh-device-token',
                'token_type': 'Bearer',
                'expires_at': DateTime.now()
                    .toUtc()
                    .add(const Duration(hours: 1))
                    .toIso8601String(),
              }),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }

          fail('Unexpected request: ${request.method} ${request.url}');
        }),
        tokenStore: tokenStore,
        installationIdStore: installationIdStore,
        secureStorage: secureStorage,
      );

      final DeviceSelfStatus status = await service.getSelfStatus();

      expect(statusCalls, 2);
      expect(status.deviceIdentifier, 'device-123');
      expect(status.isRegistered, isTrue);
      expect(tokenStore.clearCalled, isTrue);
      expect(tokenStore.savedCredentials?.accessToken, 'fresh-device-token');
    });

    test('does not auto-authenticate when disabled', () async {
      final DeviceApiService service = DeviceApiService(
        baseUrl: 'http://localhost:8080/api',
        autoAuthenticate: false,
        installationIdStore: FixedInstallationIdStore('device-123'),
        client: MockClient((http.Request request) async {
          expect(request.url.path.endsWith(DeviceApiEndpoints.deviceStatus), isTrue);
          return http.Response('unauthorized', 401);
        }),
      );

      await expectLater(
        service.getSelfStatus,
        throwsA(
          isA<ApiException>().having(
            (ApiException error) => error.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });

    test('reports a user-friendly message when device key material is missing', () async {
      final DeviceApiService service = DeviceApiService(
        baseUrl: 'http://localhost:8080/api',
        tokenStore: FakeDeviceAuthTokenStore(),
        installationIdStore: FixedInstallationIdStore('device-123'),
        secureStorage: FakeFlutterSecureStorage(),
        client: MockClient((http.Request request) async {
          if (request.url.path.endsWith(DeviceApiEndpoints.deviceAuthChallenge)) {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'encrypted_challenge': <String, dynamic>{
                  'ciphertext': base64Encode(<int>[1, 2, 3]),
                  'nonce': base64Encode(List<int>.filled(24, 1)),
                  'ephemeral_public_key': base64Encode(List<int>.filled(32, 2)),
                  'algorithm': 'x25519-hkdf-xchacha20poly1305',
                },
              }),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }

          fail('Unexpected request: ${request.method} ${request.url}');
        }),
      );

      await expectLater(
        service.getSelfStatus,
        throwsA(
          isA<ApiException>().having(
            (ApiException error) => error.message,
            'message',
            'You are not in any groups yet.',
          ),
        ),
      );
    });
  });
}

Future<Map<String, dynamic>> _buildEncryptedChallenge({
  required String publicKeyB64,
  required String plaintext,
}) async {
  final String envelope = await EyesOnlyCrypto.wrapForPublicKey(
    utf8.encode(plaintext),
    publicKeyB64,
    deviceAuthHkdfInfo,
  );
  return jsonDecode(utf8.decode(base64Decode(envelope)))
      as Map<String, dynamic>;
}

Future<_DeviceKeyMaterial> _createDeviceKeyMaterial() async {
  final KeyPair keyPair = await X25519().newKeyPair();
  final SimpleKeyPairData keyPairData =
      await keyPair.extract() as SimpleKeyPairData;
  return _DeviceKeyMaterial(
    privateKeyB64: base64Encode(keyPairData.bytes),
    publicKeyB64: base64Encode(keyPairData.publicKey.bytes),
  );
}

class _DeviceKeyMaterial {
  const _DeviceKeyMaterial({
    required this.privateKeyB64,
    required this.publicKeyB64,
  });

  final String privateKeyB64;
  final String publicKeyB64;
}

class FakeFlutterSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _values = <String, String>{};

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

class FakeAuthTokenStore extends AuthTokenStore {
  FakeAuthTokenStore({this.accessToken, this.refreshToken});

  final String? accessToken;
  final String? refreshToken;
  bool clearCalled = false;
  String? savedAccessToken;
  String? savedRefreshToken;

  @override
  Future<void> clearTokens() async {
    clearCalled = true;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens({required String accessToken, String? refreshToken}) async {
    savedAccessToken = accessToken;
    savedRefreshToken = refreshToken;
  }
}

class FakeDeviceAuthTokenStore extends DeviceAuthTokenStore {
  FakeDeviceAuthTokenStore({DeviceAuthCredentials? credentials})
    : _credentials = credentials;

  DeviceAuthCredentials? _credentials;
  bool clearCalled = false;
  DeviceAuthCredentials? savedCredentials;

  @override
  Future<void> clearCredentials() async {
    clearCalled = true;
    _credentials = null;
  }

  @override
  Future<DeviceAuthCredentials?> readCredentials() async => _credentials;

  @override
  Future<void> saveCredentials(DeviceAuthCredentials credentials) async {
    _credentials = credentials;
    savedCredentials = credentials;
  }
}

class FixedInstallationIdStore extends InstallationIdStore {
  FixedInstallationIdStore(this.installationId);

  final String installationId;

  @override
  Future<String> getOrCreateInstallationId() async => installationId;
}