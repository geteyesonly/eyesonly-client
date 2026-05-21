import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'crypto/eyes_only_crypto.dart';

const String _cacheEncryptionKeyStorageKey =
  'secure_decrypted_image_cache_key_v2';
const String _cacheDirectoryName = 'secure_decrypted_image_cache_v2';
const String _cacheEntryFileExtension = '.cache';
const Duration _cacheTtl = Duration(days: 1);

class SecureEncryptedImageBlobCacheEntry {
  const SecureEncryptedImageBlobCacheEntry({
    required this.encryptedBlobBytes,
  });

  final Uint8List encryptedBlobBytes;
}

class SecureEncryptedImageBlobCache {
  SecureEncryptedImageBlobCache({
    FlutterSecureStorage? secureStorage,
    Future<Directory> Function()? directoryProvider,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _directoryProvider = directoryProvider;

  final FlutterSecureStorage _secureStorage;
  final Future<Directory> Function()? _directoryProvider;

  Future<SecureEncryptedImageBlobCacheEntry?> read(String imageUuid) async {
    final File file = await _fileForImageUuid(imageUuid);
    if (!await file.exists()) {
      return null;
    }

    try {
      final Map<String, dynamic> encodedEntry = jsonDecode(
        await file.readAsString(),
      ) as Map<String, dynamic>;
      final int cachedAtMs = (encodedEntry['cached_at_ms'] as int?) ?? 0;
      final DateTime cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedAtMs);
      if (DateTime.now().toUtc().difference(cachedAt.toUtc()) > _cacheTtl) {
        await file.delete();
        return null;
      }

      final String ciphertext =
          (encodedEntry['ciphertext'] as String?)?.trim() ?? '';
      final String nonce = (encodedEntry['nonce'] as String?)?.trim() ?? '';
      if (ciphertext.isEmpty || nonce.isEmpty) {
        await file.delete();
        return null;
      }

      final List<int> plainBytes = await EyesOnlyCrypto.symmetricDecrypt(
        ciphertext,
        nonce,
        await _getOrCreateEncryptionKey(),
      );
      final dynamic decodedPayload = jsonDecode(utf8.decode(plainBytes));
      if (decodedPayload is! Map<String, dynamic>) {
        await file.delete();
        return null;
      }

      final String encryptedBlobB64 =
          (decodedPayload['encrypted_blob_bytes'] as String?)?.trim() ?? '';
      if (encryptedBlobB64.isEmpty) {
        await file.delete();
        return null;
      }

      return SecureEncryptedImageBlobCacheEntry(
        encryptedBlobBytes: Uint8List.fromList(base64Decode(encryptedBlobB64)),
      );
    } catch (_) {
      try {
        await file.delete();
      } catch (_) {}
      return null;
    }
  }

  Future<void> write({
    required String imageUuid,
    required Uint8List encryptedBlobBytes,
  }) async {
    final Directory directory = await _cacheDirectory();
    final File file = File('${directory.path}/${await _hashedFileName(imageUuid)}');
    final Map<String, dynamic> payload = <String, dynamic>{
      'encrypted_blob_bytes': base64Encode(encryptedBlobBytes),
    };
    final ({String ciphertext, String nonce}) encryptedPayload =
        await EyesOnlyCrypto.symmetricEncrypt(
          utf8.encode(jsonEncode(payload)),
          await _getOrCreateEncryptionKey(),
        );
    final Map<String, dynamic> encodedEntry = <String, dynamic>{
      'cached_at_ms': DateTime.now().toUtc().millisecondsSinceEpoch,
      'ciphertext': encryptedPayload.ciphertext,
      'nonce': encryptedPayload.nonce,
    };
    await file.writeAsString(jsonEncode(encodedEntry), flush: true);
  }

  Future<void> pruneToActiveImageUuids(Set<String> activeImageUuids) async {
    final Directory directory = await _cacheDirectory();
    if (!await directory.exists()) {
      return;
    }

    final Set<String> allowedFileNames = <String>{
      for (final String imageUuid in activeImageUuids) await _hashedFileName(imageUuid),
    };
    await for (final FileSystemEntity entity in directory.list()) {
      if (entity is! File) {
        continue;
      }

      final String fileName = entity.uri.pathSegments.isNotEmpty
          ? entity.uri.pathSegments.last
          : '';
      final bool shouldDeleteForId = !allowedFileNames.contains(fileName);
      final bool shouldDeleteForAge = await _isExpired(entity);
      if (!shouldDeleteForId && !shouldDeleteForAge) {
        continue;
      }

      try {
        await entity.delete();
      } catch (_) {}
    }
  }

  Future<void> clear() async {
    final Directory directory = await _cacheDirectory();
    if (await directory.exists()) {
      try {
        await directory.delete(recursive: true);
      } catch (_) {}
    }
    await _secureStorage.delete(key: _cacheEncryptionKeyStorageKey);
  }

  Future<void> remove(String imageUuid) async {
    final File file = await _fileForImageUuid(imageUuid);
    if (!await file.exists()) {
      return;
    }

    try {
      await file.delete();
    } catch (_) {}
  }

  Future<bool> _isExpired(File file) async {
    try {
      final Map<String, dynamic> encodedEntry = jsonDecode(
        await file.readAsString(),
      ) as Map<String, dynamic>;
      final int cachedAtMs = (encodedEntry['cached_at_ms'] as int?) ?? 0;
      if (cachedAtMs <= 0) {
        return true;
      }
      final DateTime cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedAtMs);
      return DateTime.now().toUtc().difference(cachedAt.toUtc()) > _cacheTtl;
    } catch (_) {
      return true;
    }
  }

  Future<File> _fileForImageUuid(String imageUuid) async {
    final Directory directory = await _cacheDirectory();
    return File('${directory.path}/${await _hashedFileName(imageUuid)}');
  }

  Future<Directory> _cacheDirectory() async {
    final Directory parent = await (_directoryProvider?.call() ?? getTemporaryDirectory());
    final Directory directory = Directory('${parent.path}/$_cacheDirectoryName');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<List<int>> _getOrCreateEncryptionKey() async {
    final String? existingKeyB64 = await _secureStorage.read(
      key: _cacheEncryptionKeyStorageKey,
    );
    if (existingKeyB64 != null && existingKeyB64.isNotEmpty) {
      return base64Decode(existingKeyB64);
    }

    final List<int> keyBytes = await EyesOnlyCrypto.generateKey();
    await _secureStorage.write(
      key: _cacheEncryptionKeyStorageKey,
      value: base64Encode(keyBytes),
    );
    return keyBytes;
  }

  Future<String> _hashedFileName(String imageUuid) async {
    final Hash hash = await Sha256().hash(utf8.encode(imageUuid));
    final String hex = hash.bytes
        .map((int value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '$hex$_cacheEntryFileExtension';
  }
}
