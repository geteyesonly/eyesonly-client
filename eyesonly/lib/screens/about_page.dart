import 'package:eyesonly/services/installation_id_store.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'App Version',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            SelectableText(_versionLabel),
            const SizedBox(height: 20),
            const Text(
              'Installation Identifier',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            SelectableText(_showInstallationId ? _installationId : 'Hidden'),
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
                _showInstallationId ? 'Hide Identifier' : 'Show Identifier',
              ),
            ),
          ],
        ),
      ),
    );
  }
}