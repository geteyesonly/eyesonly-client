import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ShareOrganizationQrPage extends StatelessWidget {
  const ShareOrganizationQrPage({
    super.key,
    required this.organizationName,
    required this.apiUrl,
  });

  final String organizationName;
  final String apiUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share Organization')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  organizationName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                QrImageView(
                  data: apiUrl,
                  version: QrVersions.auto,
                  size: 280,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 24),
                Text(
                  'Have the other device scan this QR code to add this organization.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                SelectableText(
                  apiUrl,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}