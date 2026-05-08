import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String groupKeyScopeGroupShared = 'group_shared';
const String groupKeyScopeManagerRoster = 'manager_roster';

class GroupContentKeyStore {
  GroupContentKeyStore({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _prefix = 'manager_group_content_key_';
  final FlutterSecureStorage _secureStorage;

  String _storageKey(String groupId, String scope) => '$_prefix$scope::$groupId';

  Future<void> saveGroupContentKey(
    String groupId,
    List<int> keyBytes, {
    String scope = groupKeyScopeGroupShared,
  }) async {
    await _secureStorage.write(
      key: _storageKey(groupId, scope),
      value: base64Encode(keyBytes),
    );
  }

  Future<List<int>?> readGroupContentKey(
    String groupId, {
    String scope = groupKeyScopeGroupShared,
  }) async {
    String? stored = await _secureStorage.read(key: _storageKey(groupId, scope));
    if ((stored == null || stored.isEmpty) && scope == groupKeyScopeGroupShared) {
      // Backward-compatible fallback for pre-scope storage.
      stored = await _secureStorage.read(key: '$_prefix$groupId');
    }
    if (stored == null || stored.isEmpty) {
      return null;
    }

    try {
      final List<int> keyBytes = base64Decode(stored);
      if (keyBytes.length != 32) {
        return null;
      }
      return keyBytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    final Map<String, String> storedValues = await _secureStorage.readAll();
    for (final String key in storedValues.keys) {
      if (!key.startsWith(_prefix)) {
        continue;
      }
      await _secureStorage.delete(key: key);
    }
  }
}