import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AppOrganization {
  const AppOrganization({
    required this.id,
    required this.name,
    required this.apiUrl,
  });

  final String id;
  final String name;
  final String apiUrl;

  Map<String, String> toJson() => <String, String>{
    'id': id,
    'name': name,
    'apiUrl': apiUrl,
  };

  factory AppOrganization.fromJson(Map<String, dynamic> json) {
    return AppOrganization(
      id: (json['id'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      apiUrl: (json['apiUrl'] as String?)?.trim() ?? '',
    );
  }
}

class AppSettings {
  const AppSettings({
    required this.managerModeEnabled,
    required this.useBiometricLock,
    required this.darkMode,
    required this.pushNotificationsEnabled,
    required this.managerServerURL,
    required this.lastLoggedInUsername,
    required this.deviceServerURLs,
    required this.organizations,
  });

  final bool managerModeEnabled;
  final bool useBiometricLock;
  final bool darkMode;
  final bool pushNotificationsEnabled;
  final String? managerServerURL;
  final String? lastLoggedInUsername;
  final List<String> deviceServerURLs;
  final List<AppOrganization> organizations;

  static const AppSettings defaults = AppSettings(
    managerModeEnabled: false,
    useBiometricLock: false,
    darkMode: false,
    pushNotificationsEnabled: false,
    managerServerURL: null,
    lastLoggedInUsername: null,
    deviceServerURLs: [],
    organizations: [],
  );
}

class SettingsStore {
  static const String managerModeEnabledKey = 'manager_mode_enabled';
  static const String useBiometricLockKey = 'use_biometric_lock';
  static const String darkModeKey = 'dark_mode';
  static const String pushNotificationsEnabledKey = 'push_notifications_enabled';
  static const String managerServerURLKey = 'server_url';
  static const String lastLoggedInUsernameKey = 'last_logged_in_username';
  static const String deviceServerURLsKey = 'device_server_urls';
  static const String organizationsKey = 'organizations';

  Future<AppSettings> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> deviceServerUrls =
        prefs.getStringList(deviceServerURLsKey) ??
        AppSettings.defaults.deviceServerURLs;
    final List<AppOrganization> organizations = _readOrganizations(prefs);

    return AppSettings(
      managerModeEnabled:
          prefs.getBool(managerModeEnabledKey) ??
          AppSettings.defaults.managerModeEnabled,
      useBiometricLock:
          prefs.getBool(useBiometricLockKey) ??
          AppSettings.defaults.useBiometricLock,
      darkMode: prefs.getBool(darkModeKey) ?? AppSettings.defaults.darkMode,
      pushNotificationsEnabled:
          prefs.getBool(pushNotificationsEnabledKey) ??
          AppSettings.defaults.pushNotificationsEnabled,
      managerServerURL:
          prefs.getString(managerServerURLKey) ?? AppSettings.defaults.managerServerURL,
      lastLoggedInUsername:
          prefs.getString(lastLoggedInUsernameKey) ??
          AppSettings.defaults.lastLoggedInUsername,
      deviceServerURLs: deviceServerUrls,
      organizations: organizations,
    );
  }

  List<AppOrganization> _readOrganizations(SharedPreferences prefs) {
    final List<String> encodedOrganizations =
        prefs.getStringList(organizationsKey) ?? const <String>[];
    final List<AppOrganization> organizations = <AppOrganization>[];

    for (final String encoded in encodedOrganizations) {
      try {
        final dynamic decoded = jsonDecode(encoded);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        final AppOrganization organization = AppOrganization.fromJson(decoded);
        if (organization.id.isEmpty ||
            organization.name.isEmpty ||
            organization.apiUrl.isEmpty) {
          continue;
        }
        organizations.add(organization);
      } catch (_) {
        continue;
      }
    }

    return organizations;
  }

  Future<void> saveOrganizations(List<AppOrganization> organizations) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> normalizedUrls = organizations
        .map((AppOrganization organization) => organization.apiUrl.trim())
        .where((String url) => url.isNotEmpty)
        .toSet()
        .toList();
    final List<String> encodedOrganizations = organizations
        .map((AppOrganization organization) => jsonEncode(organization.toJson()))
        .toList();

    await prefs.setStringList(organizationsKey, encodedOrganizations);
    await prefs.setStringList(deviceServerURLsKey, normalizedUrls);
  }

  Future<void> upsertOrganization(AppOrganization organization) async {
    final AppOrganization normalizedOrganization = AppOrganization(
      id: organization.id.trim(),
      name: organization.name.trim(),
      apiUrl: organization.apiUrl.trim(),
    );
    if (normalizedOrganization.id.isEmpty ||
        normalizedOrganization.name.isEmpty ||
        normalizedOrganization.apiUrl.isEmpty) {
      return;
    }

    final AppSettings settings = await load();
    final List<AppOrganization> organizations =
        List<AppOrganization>.from(settings.organizations);
    final int existingIndex = organizations.indexWhere(
      (AppOrganization current) =>
          current.apiUrl.trim() == normalizedOrganization.apiUrl,
    );

    if (existingIndex >= 0) {
      organizations[existingIndex] = AppOrganization(
        id: organizations[existingIndex].id,
        name: normalizedOrganization.name,
        apiUrl: normalizedOrganization.apiUrl,
      );
    } else {
      organizations.add(normalizedOrganization);
    }

    await saveOrganizations(organizations);
  }

  Future<void> saveDeviceServerURLs(List<String> urls) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(deviceServerURLsKey, urls);
  }

  Future<void> saveManagerModeEnabled(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(managerModeEnabledKey, value);
  }

  Future<void> saveUseBiometricLock(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(useBiometricLockKey, value);
  }

  Future<void> saveDarkMode(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(darkModeKey, value);
  }

  Future<void> savePushNotificationsEnabled(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(pushNotificationsEnabledKey, value);
  }

  Future<void> saveManagerServerURL(String? value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(managerServerURLKey);
    } else {
      await prefs.setString(managerServerURLKey, value);
    }
  }

  Future<void> saveLastLoggedInUsername(String? value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      await prefs.remove(lastLoggedInUsernameKey);
      return;
    }
    await prefs.setString(lastLoggedInUsernameKey, normalizedValue);
  }

  Future<void> clearAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(managerModeEnabledKey);
    await prefs.remove(useBiometricLockKey);
    await prefs.remove(darkModeKey);
    await prefs.remove(pushNotificationsEnabledKey);
    await prefs.remove(managerServerURLKey);
    await prefs.remove(lastLoggedInUsernameKey);
    await prefs.remove(deviceServerURLsKey);
    await prefs.remove(organizationsKey);
  }
}
