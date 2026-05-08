import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:eyesonly/screens/add_organization_page.dart';
import 'package:eyesonly/services/api_exception.dart';
import 'package:eyesonly/services/push_notifications_service.dart';
import 'package:eyesonly/services/reset_service.dart';
import 'package:eyesonly/services/secure_decrypted_image_cache.dart';
import 'package:eyesonly/services/settings_store.dart';

typedef SettingsDeviceSupportChecker = Future<bool> Function();
typedef SettingsDeviceAuthenticator = Future<bool> Function();

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.localAuthentication,
    this.settingsStore,
    this.imageCache,
    this.resetAppAction,
    this.deviceSupportChecker,
    this.deviceAuthenticator,
    this.pushNotificationsService,
  });

  final LocalAuthentication? localAuthentication;
  final SettingsStore? settingsStore;
  final SecureDecryptedImageCache? imageCache;
  final Future<void> Function()? resetAppAction;
  final SettingsDeviceSupportChecker? deviceSupportChecker;
  final SettingsDeviceAuthenticator? deviceAuthenticator;
  final PushNotificationsService? pushNotificationsService;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final LocalAuthentication _localAuthentication;
  late final SettingsStore _settingsStore;
  late final SecureDecryptedImageCache _imageCache;
  late final PushNotificationsService _pushNotificationsService;
  String? _managerServerURL;
  bool _managerModeEnabled = AppSettings.defaults.managerModeEnabled;
  bool _useBiometricLock = AppSettings.defaults.useBiometricLock;
  bool _darkMode = AppSettings.defaults.darkMode;
  bool _pushNotificationsEnabled = AppSettings.defaults.pushNotificationsEnabled;
  bool _isUpdatingPushNotifications = false;
  bool _isLoading = true;
  bool _isClearingImageCache = false;
  List<AppOrganization> _organizations = <AppOrganization>[];

  @override
  void initState() {
    super.initState();
    _localAuthentication = widget.localAuthentication ?? LocalAuthentication();
    _settingsStore = widget.settingsStore ?? SettingsStore();
    _imageCache = widget.imageCache ?? SecureDecryptedImageCache();
    _pushNotificationsService =
      widget.pushNotificationsService ?? PushNotificationsService();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final AppSettings settings = await _settingsStore.load();

    if (!mounted) {
      return;
    }

    setState(() {
      _managerModeEnabled = settings.managerModeEnabled;
      _useBiometricLock = settings.useBiometricLock;
      _darkMode = settings.darkMode;
      _pushNotificationsEnabled = settings.pushNotificationsEnabled;
      _managerServerURL = settings.managerServerURL;
      _organizations = List<AppOrganization>.from(settings.organizations)
        ..sort(
          (AppOrganization a, AppOrganization b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      _isLoading = false;
    });

    // Auto-select sole org as manager server if manager mode is on and none selected.
    if (_managerModeEnabled && _managerServerURL == null && _organizations.length == 1) {
      await _saveManagerServerUrl(_organizations.first.apiUrl);
    }
  }

  Future<void> _openAddOrganizationPage() async {
    final bool? added = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => const AddOrganizationPage(),
      ),
    );

    if (added == true) {
      await _loadSettings();
      // If this was the first org added and manager mode is on, auto-select it.
      if (_managerModeEnabled && _managerServerURL == null && _organizations.length == 1) {
        await _saveManagerServerUrl(_organizations.first.apiUrl);
      }
    }
  }

  Future<void> _removeOrganization(AppOrganization organization) async {
    final List<AppOrganization> updatedOrganizations = _organizations
        .where((AppOrganization next) => next.id != organization.id)
        .toList();
    setState(() {
      _organizations = updatedOrganizations;
    });
    await _settingsStore.saveOrganizations(updatedOrganizations);
  }

  Future<void> _confirmRemoveOrganization(AppOrganization organization) async {
    final bool? shouldRemove = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Organization'),
          content: Text(
            'Do you want to remove ${organization.name} from this device?\n\nThis only removes the local organization entry.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (shouldRemove == true) {
      await _removeOrganization(organization);
    }
  }

  Future<void> _saveManagerServerUrl(String? value) async {
    setState(() {
      _managerServerURL = value;
    });
    await _settingsStore.saveManagerServerURL(value);
  }

  Future<void> _setBiometricLock(bool value) async {
    if (!value) {
      setState(() {
        _useBiometricLock = false;
      });
      await _settingsStore.saveUseBiometricLock(false);
      return;
    }

    final bool isDeviceSupported = await (widget.deviceSupportChecker?.call() ??
      _localAuthentication.isDeviceSupported());
    if (!isDeviceSupported) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No device authentication is available on this device.'),
        ),
      );
      setState(() {
        _useBiometricLock = false;
      });
      return;
    }

    final bool didAuthenticate = await (widget.deviceAuthenticator?.call() ??
        _localAuthentication.authenticate(
          localizedReason: 'Confirm device lock for Eyes Only',
          options: const AuthenticationOptions(
            stickyAuth: true,
          ),
        ));

    if (!mounted) {
      return;
    }

    if (!didAuthenticate) {
      setState(() {
        _useBiometricLock = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device lock was not enabled.')),
      );
      return;
    }

    setState(() {
      _useBiometricLock = true;
    });
    await _settingsStore.saveUseBiometricLock(true);
  }

  Future<void> _resetApp() async {
    await (widget.resetAppAction?.call() ?? ResetService.resetApp());
    if (!mounted) {
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _clearImageCache() async {
    if (_isClearingImageCache) {
      return;
    }

    final bool? shouldClear = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Image Cache'),
          content: const Text(
            'Delete all locally cached images from this device?\n\nThe next time you open Photos, images will be fetched again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete Cache'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true) {
      return;
    }

    setState(() {
      _isClearingImageCache = true;
    });

    try {
      await _imageCache.clear();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image cache deleted.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete image cache: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isClearingImageCache = false;
        });
      }
    }
  }

  Future<void> _setPushNotificationsEnabled(bool value) async {
    final List<String> organizationUrls = _organizations
        .map((AppOrganization organization) => organization.apiUrl.trim())
        .where((String apiUrl) => apiUrl.isNotEmpty)
        .toSet()
        .toList();
    final String? fallbackBaseUrl = _managerServerURL?.trim();
    if (organizationUrls.isEmpty &&
        (fallbackBaseUrl == null || fallbackBaseUrl.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an organization first.'),
        ),
      );
      return;
    }

    setState(() {
      _isUpdatingPushNotifications = true;
    });

    try {
      if (value) {
        await _pushNotificationsService.enableForOrganizations(
          baseUrls: organizationUrls,
          fallbackBaseUrl: fallbackBaseUrl,
        );
      } else {
        await _pushNotificationsService.disableForOrganizations(
          baseUrls: organizationUrls,
          fallbackBaseUrl: fallbackBaseUrl,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _pushNotificationsEnabled = value;
      });
      await _settingsStore.savePushNotificationsEnabled(value);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update push notifications: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingPushNotifications = false;
        });
      }
    }
  }

  void _showResetAppDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset App'),
          content: const Text(
            'Warning: Resetting the app will remove local keys, tokens, installation identity, organizations, cached images, and app settings. This action cannot be undone.\n\nAre you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _resetApp();
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          // General Section
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text('General', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(
            title: const Text('Device Lock'),
            subtitle: const Text('Require face, fingerprint, or device code'),
            value: _useBiometricLock,
            onChanged: (value) async {
              await _setBiometricLock(value);
            },
          ),
          SwitchListTile(
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive notifications when new pictures are uploaded'),
            value: _pushNotificationsEnabled,
            onChanged: _isUpdatingPushNotifications
                ? null
                : _setPushNotificationsEnabled,
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Use a darker appearance at night'),
            value: _darkMode,
            onChanged: (value) async {
              setState(() {
                _darkMode = value;
              });
              await _settingsStore.saveDarkMode(value);
            },
          ),
          SwitchListTile(
            title: const Text('Manager Mode'),
            subtitle: const Text('Enable manager mode features'),
            value: _managerModeEnabled,
            onChanged: (value) async {
              setState(() {
                _managerModeEnabled = value;
              });
              await _settingsStore.saveManagerModeEnabled(value);
              // Auto-select sole org when manager mode is turned on.
              if (value && _managerServerURL == null && _organizations.length == 1) {
                await _saveManagerServerUrl(_organizations.first.apiUrl);
              }
            },
          ),
          const Divider(),

          // Organizations Section
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text('Organizations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          if (_organizations.isEmpty)
            const ListTile(
              title: Text('No organizations yet'),
              subtitle: Text('Add an organization to connect this device.'),
            )
          else
            ..._organizations.map((AppOrganization organization) {
              return ListTile(
                leading: const Icon(Icons.apartment_outlined),
                title: Text(organization.name),
                subtitle: Text(organization.apiUrl),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await _confirmRemoveOrganization(organization);
                  },
                ),
              );
            }),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _openAddOrganizationPage,
                icon: const Icon(Icons.add_business),
                label: const Text('Add Organization'),
              ),
            ),
          ),
          if (_managerModeEnabled) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text('Manager Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: _organizations.isEmpty
                  ? const Text(
                      'Add an organization first to select a manager server.',
                      style: TextStyle(color: Colors.grey),
                    )
                  : DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Manager Organization',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _organizations.any(
                        (AppOrganization o) => o.apiUrl == _managerServerURL,
                      )
                          ? _managerServerURL
                          : null,
                      items: _organizations
                          .map(
                            (AppOrganization o) => DropdownMenuItem<String>(
                              value: o.apiUrl,
                              child: Text(o.name),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) async {
                        await _saveManagerServerUrl(value);
                      },
                    ),
            ),
          ],

          const Divider(),
          ListTile(
            leading: _isClearingImageCache
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cleaning_services_outlined),
            title: const Text('Delete Image Cache'),
            subtitle: const Text('Remove locally cached decrypted images'),
            enabled: !_isClearingImageCache,
            onTap: _clearImageCache,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Reset App'),
            subtitle: const Text('Remove local keys, tokens, organizations, and app settings'),
            textColor: Theme.of(context).colorScheme.error,
            iconColor: Theme.of(context).colorScheme.error,
            onTap: _showResetAppDialog,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            subtitle: const Text('1.0.0'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
