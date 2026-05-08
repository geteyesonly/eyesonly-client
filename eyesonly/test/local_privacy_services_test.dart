import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:test/test.dart';

import 'package:eyesonly/services/device/auth_token_store.dart';
import 'package:eyesonly/services/installation_id_store.dart';
import 'package:eyesonly/services/manager/auth_token_store.dart';
import 'package:eyesonly/services/manager/device_registration_keys.dart';
import 'package:eyesonly/services/manager/group_content_key_store.dart';
import 'package:eyesonly/services/reset_service.dart';
import 'package:eyesonly/services/secure_decrypted_image_cache.dart';
import 'package:eyesonly/services/settings_store.dart';

void main() {
  group('SecureDecryptedImageCache', () {
    late Directory tempRoot;
    late FakeFlutterSecureStorage secureStorage;
    late SecureDecryptedImageCache cache;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('eyesonly-cache-test-');
      secureStorage = FakeFlutterSecureStorage();
      cache = SecureDecryptedImageCache(
        secureStorage: secureStorage,
        directoryProvider: () async => tempRoot,
      );
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('writes and reads decrypted image data roundtrip', () async {
      await cache.write(
        imageUuid: 'image-1',
        imageBytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
        caption: 'hello',
      );

      final SecureDecryptedImageCacheEntry? entry = await cache.read('image-1');

      expect(entry, isNotNull);
      expect(entry!.imageBytes, Uint8List.fromList(<int>[1, 2, 3, 4]));
      expect(entry.caption, 'hello');
      expect(secureStorage.writtenKeys, contains('secure_decrypted_image_cache_key_v2'));
    });

    test('returns null and deletes expired cache entries', () async {
      await cache.write(
        imageUuid: 'image-expired',
        imageBytes: Uint8List.fromList(<int>[9, 8, 7]),
      );
      final File cacheFile = await _singleCacheFile(tempRoot);
      final Map<String, dynamic> payload = jsonDecode(await cacheFile.readAsString())
          as Map<String, dynamic>;
      payload['cached_at_ms'] = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 2))
          .millisecondsSinceEpoch;
      await cacheFile.writeAsString(jsonEncode(payload));

      final SecureDecryptedImageCacheEntry? entry = await cache.read('image-expired');

      expect(entry, isNull);
      expect(await cacheFile.exists(), isFalse);
    });

    test('returns null and deletes corrupt cache entries', () async {
      await cache.write(
        imageUuid: 'image-corrupt',
        imageBytes: Uint8List.fromList(<int>[1]),
      );
      final File cacheFile = await _singleCacheFile(tempRoot);
      await cacheFile.writeAsString('{not json');

      final SecureDecryptedImageCacheEntry? entry = await cache.read('image-corrupt');

      expect(entry, isNull);
      expect(await cacheFile.exists(), isFalse);
    });

    test('prunes inactive cache entries', () async {
      await cache.write(
        imageUuid: 'keep-image',
        imageBytes: Uint8List.fromList(<int>[1, 2]),
      );
      await cache.write(
        imageUuid: 'drop-image',
        imageBytes: Uint8List.fromList(<int>[3, 4]),
      );

      await cache.pruneToActiveImageUuids(<String>{'keep-image'});

      expect(await cache.read('keep-image'), isNotNull);
      expect(await cache.read('drop-image'), isNull);
    });
  });

  group('ResetService', () {
    test('clears all targeted local state stores', () async {
      final FakeDeviceAuthTokenStore deviceAuthTokenStore = FakeDeviceAuthTokenStore();
      final FakeAuthTokenStore managerAuthTokenStore = FakeAuthTokenStore();
      final FakeSecureDecryptedImageCache imageCache = FakeSecureDecryptedImageCache();
      final FakeGroupContentKeyStore groupContentKeyStore = FakeGroupContentKeyStore();
      final FakeInstallationIdStore installationIdStore = FakeInstallationIdStore();
      final FakeFlutterSecureStorage secureStorage = FakeFlutterSecureStorage();
      final FakeSettingsStore settingsStore = FakeSettingsStore();

      await ResetService.resetApp(
        deviceAuthTokenStore: deviceAuthTokenStore,
        managerAuthTokenStore: managerAuthTokenStore,
        imageCache: imageCache,
        groupContentKeyStore: groupContentKeyStore,
        installationIdStore: installationIdStore,
        secureStorage: secureStorage,
        settingsStore: settingsStore,
      );

      expect(deviceAuthTokenStore.clearCalled, isTrue);
      expect(managerAuthTokenStore.clearCalled, isTrue);
      expect(imageCache.clearCalled, isTrue);
      expect(groupContentKeyStore.clearAllCalled, isTrue);
      expect(installationIdStore.clearCalled, isTrue);
      expect(settingsStore.clearAllCalled, isTrue);
      expect(
        secureStorage.deletedKeys,
        containsAll(<String>[
          DeviceRegistrationKeys.privateKey,
          DeviceRegistrationKeys.publicKey,
          DeviceRegistrationKeys.registered,
          DeviceRegistrationKeys.registeredOwnerName,
        ]),
      );
    });
  });
}

Future<File> _singleCacheFile(Directory tempRoot) async {
  final Directory cacheDirectory = Directory(
    '${tempRoot.path}/secure_decrypted_image_cache_v2',
  );
  final List<FileSystemEntity> entries = await cacheDirectory.list().toList();
  return entries.single as File;
}

class FakeFlutterSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _values = <String, String>{};
  final List<String> deletedKeys = <String>[];
  final List<String> writtenKeys = <String>[];

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
    deletedKeys.add(key);
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
    writtenKeys.add(key);
    if (value == null) {
      _values.remove(key);
      return;
    }
    _values[key] = value;
  }
}

class FakeDeviceAuthTokenStore extends DeviceAuthTokenStore {
  bool clearCalled = false;

  @override
  Future<void> clearCredentials() async {
    clearCalled = true;
  }
}

class FakeAuthTokenStore extends AuthTokenStore {
  bool clearCalled = false;

  @override
  Future<void> clearTokens() async {
    clearCalled = true;
  }
}

class FakeSecureDecryptedImageCache extends SecureDecryptedImageCache {
  bool clearCalled = false;

  @override
  Future<void> clear() async {
    clearCalled = true;
  }
}

class FakeGroupContentKeyStore extends GroupContentKeyStore {
  bool clearAllCalled = false;

  @override
  Future<void> clearAll() async {
    clearAllCalled = true;
  }
}

class FakeInstallationIdStore extends InstallationIdStore {
  bool clearCalled = false;

  @override
  Future<void> clear() async {
    clearCalled = true;
  }
}

class FakeSettingsStore extends SettingsStore {
  bool clearAllCalled = false;

  @override
  Future<void> clearAll() async {
    clearAllCalled = true;
  }
}