import 'package:eyesonly/services/installation_id_store.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:eyesonly/l10n/app_localizations.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final InstallationIdStore _installationIdStore = InstallationIdStore();
  String _versionLabel = 'Loading...';
  String _installationId = 'Loading...';
  bool _showInstallationId = false;

  AppLocalizations? get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _loadAboutData();
  }

  Future<void> _loadAboutData() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String installationId =
        await _installationIdStore.getOrCreateInstallationId();

    if (!mounted) {
      return;
    }

    setState(() {
      _versionLabel = '${packageInfo.version}+${packageInfo.buildNumber}';
      _installationId = installationId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? l10n = _l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.homeTabAbout ?? 'About')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.settingsAppVersion ?? 'App Version',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            SelectableText(_versionLabel),
            const SizedBox(height: 20),
            Text(
              l10n?.aboutInstallationIdentifier ?? 'Installation Identifier',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            SelectableText(
              _showInstallationId
                  ? _installationId
                  : (l10n?.aboutHiddenValue ?? 'Hidden'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showInstallationId = !_showInstallationId;
                });
              },
              icon: Icon(
                _showInstallationId ? Icons.visibility_off : Icons.visibility,
              ),
              label: Text(
                _showInstallationId
                    ? (l10n?.aboutHideIdentifier ?? 'Hide Identifier')
                    : (l10n?.aboutShowIdentifier ?? 'Show Identifier'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}