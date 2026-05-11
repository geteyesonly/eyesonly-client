import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:eyesonly/screens/home_page.dart';
import 'package:eyesonly/screens/onboarding_page.dart';
import 'package:eyesonly/services/installation_id_store.dart';
import 'package:eyesonly/services/push_notifications_service.dart';
import 'package:eyesonly/services/settings_store.dart';
import 'package:screen_protector/screen_protector.dart';

typedef DeviceSupportChecker = Future<bool> Function();
typedef DeviceAuthenticator = Future<bool> Function();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _enableScreenProtection();
  await InstallationIdStore().getOrCreateInstallationId();
  final AppSettings settings = await SettingsStore().load();
  await PushNotificationsService().initializeMessageHandling();
  await PushNotificationsService().syncTokenOnAppStart(
    pushNotificationsEnabled: settings.pushNotificationsEnabled,
    baseUrls: settings.organizations.map(
      (AppOrganization organization) => organization.apiUrl,
    ),
    fallbackBaseUrl: settings.managerServerURL,
  );
  runApp(MyApp(initialSettings: settings));
}

Future<void> _enableScreenProtection() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  try {
    await ScreenProtector.preventScreenshotOn();
  } on PlatformException {
    // Ignore platform-specific failures to avoid blocking app startup.
  }
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    required this.initialSettings,
    this.settingsStore,
    this.deviceSupportChecker,
    this.deviceAuthenticator,
    this.home,
  });

  final AppSettings initialSettings;
  final SettingsStore? settingsStore;
  final DeviceSupportChecker? deviceSupportChecker;
  final DeviceAuthenticator? deviceAuthenticator;
  final Widget? home;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final LocalAuthentication _localAuthentication = LocalAuthentication();
  late final SettingsStore _settingsStore;
  late AppSettings _currentSettings;
  late bool _darkMode;
  late bool _useBiometricLock;
  bool _isLocked = false;
  bool _isAuthenticating = false;
  String? _lockMessage;
  DateTime? _ignoreLifecycleUntil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settingsStore = widget.settingsStore ?? SettingsStore();
    _currentSettings = widget.initialSettings;
    _darkMode = widget.initialSettings.darkMode;
    _useBiometricLock = widget.initialSettings.useBiometricLock;
    _isLocked = _useBiometricLock;
    if (_useBiometricLock) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _unlockApp();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final DateTime? ignoreLifecycleUntil = _ignoreLifecycleUntil;
    if (!_useBiometricLock || _isAuthenticating) {
      return;
    }

    final bool shouldIgnoreLifecycleEvent =
        ignoreLifecycleUntil != null &&
        DateTime.now().isBefore(ignoreLifecycleUntil);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (shouldIgnoreLifecycleEvent) {
        return;
      }
      if (mounted) {
        setState(() {
          _isLocked = true;
          _lockMessage = null;
        });
      }
      return;
    }
  }

  Future<void> _reloadAppSettings() async {
    final AppSettings settings = await _settingsStore.load();
    if (!mounted) {
      return;
    }

    final bool hadBiometricLock = _useBiometricLock;

    setState(() {
      _currentSettings = settings;
      _darkMode = settings.darkMode;
      _useBiometricLock = settings.useBiometricLock;
      if (!_useBiometricLock) {
        _isLocked = false;
        _lockMessage = null;
      } else if (!hadBiometricLock) {
        _isLocked = true;
      }
    });

    if (!hadBiometricLock && settings.useBiometricLock) {
      await _unlockApp();
    }
  }

  Future<void> _unlockApp() async {
    if (!_useBiometricLock || _isAuthenticating) {
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _lockMessage = null;
    });

    try {
      final bool isDeviceSupported =
          await (widget.deviceSupportChecker?.call() ??
              _localAuthentication.isDeviceSupported());
      if (!isDeviceSupported) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLocked = true;
          _lockMessage = 'No device authentication is available.';
        });
        return;
      }

      final bool didAuthenticate =
          await (widget.deviceAuthenticator?.call() ??
              _localAuthentication.authenticate(
                localizedReason: 'Unlock Eyes Only',
                options: const AuthenticationOptions(),
              ));

      if (!mounted) {
        return;
      }

      setState(() {
        _isLocked = !didAuthenticate;
        _lockMessage = didAuthenticate ? null : 'Unlock required to continue.';
      });
      if (didAuthenticate) {
        _ignoreLifecycleUntil = DateTime.now().add(const Duration(seconds: 10));
      }
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLocked = true;
        _lockMessage = error.message ?? 'Device authentication failed.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLocked = true;
        _lockMessage = 'Device authentication failed.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eyes Only',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 133, 58, 183),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 133, 58, 183),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (BuildContext context, Widget? child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (_isLocked)
              _AppLockOverlay(
                isAuthenticating: _isAuthenticating,
                message: _lockMessage,
                onUnlockPressed: _unlockApp,
              ),
          ],
        );
      },
      home:
          widget.home ??
          (_currentSettings.onboardingCompleted
              ? MyHomePage(
                  title: 'Eyes Only',
                  onSettingsChanged: _reloadAppSettings,
                )
              : OnboardingPage(
                  initialSettings: _currentSettings,
                  onCompleted: () {
                    _reloadAppSettings();
                  },
                )),
    );
  }
}

class _AppLockOverlay extends StatelessWidget {
  const _AppLockOverlay({
    required this.isAuthenticating,
    required this.message,
    required this.onUnlockPressed,
  });

  final bool isAuthenticating;
  final String? message;
  final Future<void> Function() onUnlockPressed;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Eyes Only is locked',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message ??
                        'Use face, fingerprint, or your device code to continue.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: isAuthenticating ? null : onUnlockPressed,
                    icon: isAuthenticating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fingerprint),
                    label: Text(isAuthenticating ? 'Unlocking...' : 'Unlock'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
