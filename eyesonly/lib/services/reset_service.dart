import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'device/auth_token_store.dart';
import 'installation_id_store.dart';
import 'manager/auth_token_store.dart';
import 'manager/group_content_key_store.dart';
import 'settings_store.dart';
import '../services/manager/device_registration_keys.dart';
import 'secure_decrypted_image_cache.dart';

class ResetService {
  static Future<void> resetApp({
    DeviceAuthTokenStore? deviceAuthTokenStore,
    AuthTokenStore? managerAuthTokenStore,
    SecureDecryptedImageCache? imageCache,
    GroupContentKeyStore? groupContentKeyStore,
    InstallationIdStore? installationIdStore,
    FlutterSecureStorage? secureStorage,
    SettingsStore? settingsStore,
  }) async {
    await (deviceAuthTokenStore ?? DeviceAuthTokenStore()).clearCredentials();
    await (managerAuthTokenStore ?? AuthTokenStore()).clearTokens();

    await (imageCache ?? SecureDecryptedImageCache()).clear();
    await (groupContentKeyStore ?? GroupContentKeyStore()).clearAll();
    await (installationIdStore ?? InstallationIdStore()).clear();

    final FlutterSecureStorage resolvedSecureStorage =
        secureStorage ?? const FlutterSecureStorage();
    await resolvedSecureStorage.delete(key: DeviceRegistrationKeys.privateKey);
    await resolvedSecureStorage.delete(key: DeviceRegistrationKeys.publicKey);
    await resolvedSecureStorage.delete(key: DeviceRegistrationKeys.registered);
    await resolvedSecureStorage.delete(
      key: DeviceRegistrationKeys.registeredOwnerName,
    );

    await (settingsStore ?? SettingsStore()).clearAll();
  }
}
