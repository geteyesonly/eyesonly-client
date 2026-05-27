import 'package:eyesonly/services/manager/api_service.dart';
import 'package:eyesonly/services/manager/auth_token_store.dart';
import 'package:eyesonly/screens/main_manager/login_page.dart';
import 'package:eyesonly/services/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:eyesonly/l10n/app_localizations.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, this.username});

  final String? username;

  @override
  State<AccountPage> createState() => _AccountPageState();
}


class _AccountPageState extends State<AccountPage> {
  final SettingsStore _settingsStore = SettingsStore();
  final AuthTokenStore _tokenStore = AuthTokenStore();
  bool _isLoggingOut = false;
  bool _isCheckingSession = true;

  AppLocalizations? get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _ensureActiveSession();
  }

  Future<void> _ensureActiveSession() async {
    final String? accessToken = await _tokenStore.readAccessToken();
    final bool hasSession = accessToken != null && accessToken.trim().isNotEmpty;
    if (!mounted) {
      return;
    }

    if (!hasSession) {
      await _settingsStore.saveLastLoggedInUsername(null);
      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const LoginPage(),
        ),
      );
      return;
    }

    setState(() {
      _isCheckingSession = false;
    });
  }

  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    final AppSettings settings = await _settingsStore.load();
    final String? baseUrl = settings.managerServerURL?.trim();

    if (baseUrl != null && baseUrl.isNotEmpty) {
      final ManagerApiService managerApiService = ManagerApiService(
        baseUrl: baseUrl,
      );
      await managerApiService.hydrateTokens();
      try {
        await managerApiService.logout();
      } catch (_) {
        // Continue logout locally even if remote revoke fails.
      }
    }

    await _tokenStore.clearTokens();
    await _settingsStore.saveLastLoggedInUsername(null);

    if (!mounted) {
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? l10n = _l10n;

    if (_isCheckingSession) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n?.homeTabAccount ?? 'Account')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final String username = (widget.username == null || widget.username!.trim().isEmpty)
        ? (l10n?.accountNotLoggedIn ?? 'Not logged in')
        : widget.username!.trim();

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.homeTabAccount ?? 'Account')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                username,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoggingOut ? null : _logout,
                child: Text(
                  _isLoggingOut
                      ? (l10n?.accountLoggingOut ?? 'Logging Out...')
                      : (l10n?.accountLogOut ?? 'Log Out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}