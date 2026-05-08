import 'package:flutter/material.dart';
import 'package:eyesonly/services/api_exception.dart';
import 'package:eyesonly/services/device/api_service.dart';
import 'package:eyesonly/screens/join_group_qr_page.dart';
import 'package:eyesonly/services/manager/device_registration_service.dart';
import 'package:eyesonly/services/manager/api_service.dart';
import 'package:eyesonly/services/screen_feedback.dart';
import 'package:eyesonly/services/settings_store.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.settingsStore,
    this.deviceRegistrationService,
    this.managerApiServiceBuilder,
    this.deviceApiServiceBuilder,
  });

  final SettingsStore? settingsStore;
  final DeviceRegistrationService? deviceRegistrationService;
  final ManagerApiService Function(String baseUrl)? managerApiServiceBuilder;
  final DeviceApiService Function(String baseUrl)? deviceApiServiceBuilder;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final SettingsStore _settingsStore;
  late final DeviceRegistrationService _deviceRegistrationService;
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _settingsStore = widget.settingsStore ?? SettingsStore();
    _deviceRegistrationService =
        widget.deviceRegistrationService ?? DeviceRegistrationService();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showDeviceRegistrationPrompt({
    required String baseUrl,
    required String organizationName,
  }) async {
    final bool? showQr = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Register This Device'),
          content: const Text(
            'This device is not registered yet. On your already-registered manager device, tap "Register Manager Device" and scan the QR code shown here.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Show QR Code'),
            ),
          ],
        );
      },
    );
    if (showQr == true && mounted) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (BuildContext context) => JoinGroupQrPage(
            organizationName: organizationName,
            apiUrl: baseUrl,
          ),
        ),
      );
    }
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final AppSettings settings = await _settingsStore.load();
      final String? baseUrl = settings.managerServerURL?.trim();
      final String username = _usernameController.text.trim();
      if (baseUrl == null || baseUrl.isEmpty) {
        throw ApiException('Server URL is not set. Configure it in Settings.');
      }

      final ManagerApiService managerApiService =
          widget.managerApiServiceBuilder?.call(baseUrl) ??
          ManagerApiService(baseUrl: baseUrl);
      await managerApiService.hydrateTokens();
      await managerApiService.login(
        username: username,
        password: _passwordController.text,
      );
      final bool isCurrentDeviceRegistered = await _deviceRegistrationService
          .isCurrentDeviceRegistered(
            managerApiService: managerApiService,
          );
      bool hasExistingManagerOwnedDevice = false;
      if (!isCurrentDeviceRegistered) {
        hasExistingManagerOwnedDevice = await _deviceRegistrationService
            .hasExistingManagerOwnedDevice(
              managerApiService: managerApiService,
            );
        if (!hasExistingManagerOwnedDevice) {
          await _deviceRegistrationService.ensureRegistered(
            managerApiService: managerApiService,
            username: username,
          );
        }
      }

      String organizationName = baseUrl;
      try {
        final DeviceApiService deviceApiService =
            widget.deviceApiServiceBuilder?.call(baseUrl) ??
            DeviceApiService(baseUrl: baseUrl);
        final DeviceSelfStatus selfStatus = await deviceApiService.getSelfStatus();
        final String resolvedOrganizationName =
            selfStatus.organizationName?.trim() ?? '';
        if (resolvedOrganizationName.isNotEmpty) {
          organizationName = resolvedOrganizationName;
        }
      } catch (_) {
        // Fall back to the server URL when organization metadata is unavailable.
      }

      await _settingsStore.upsertOrganization(
        AppOrganization(
          id: baseUrl,
          name: organizationName,
          apiUrl: baseUrl,
        ),
      );

      await _settingsStore.saveLastLoggedInUsername(username);

      // Add manager server URL to deviceServerURLs if not present
      final List<String> urls = List<String>.from(settings.deviceServerURLs);
      if (!urls.contains(baseUrl)) {
        urls.add(baseUrl);
        await _settingsStore.saveDeviceServerURLs(urls);
      }

      if (!mounted) {
        return;
      }

      if (!isCurrentDeviceRegistered && hasExistingManagerOwnedDevice) {
        await _showDeviceRegistrationPrompt(
          baseUrl: baseUrl,
          organizationName: organizationName,
        );
        if (!mounted) {
          return;
        }
      }

      ScreenFeedback.showMessage(context, 'Login successful');
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScreenFeedback.showError(context, error);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScreenFeedback.showError(
        context,
        error,
        fallbackMessage: 'Login failed. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log In'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Manager Login',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This app supports login only. Registration is disabled.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Username is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submitLogin,
                      child: Text(_isSubmitting ? 'Logging In...' : 'Log In'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
