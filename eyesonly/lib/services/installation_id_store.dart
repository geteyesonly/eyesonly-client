import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class InstallationIdStore {
  InstallationIdStore({
    FlutterSecureStorage? secureStorage,
    Uuid? uuid,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _uuid = uuid ?? const Uuid();

  static const String _installationIdKey = 'installation_id';

  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid;

  Future<String> getOrCreateInstallationId() async {
    final String? existingId = await _secureStorage.read(
      key: _installationIdKey,
    );
    if (existingId != null && existingId.trim().isNotEmpty) {
      return existingId;
    }

    final String newId = _uuid.v4();
    await _secureStorage.write(key: _installationIdKey, value: newId);
    return newId;
  }

  Future<void> clear() async {
    await _secureStorage.delete(key: _installationIdKey);
  }
}