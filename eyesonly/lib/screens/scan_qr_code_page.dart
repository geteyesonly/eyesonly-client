import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:eyesonly/l10n/app_localizations.dart';

class ScanQrCodePage extends StatefulWidget {
  const ScanQrCodePage({
    super.key,
    this.title,
    this.instruction,
  });

  final String? title;
  final String? instruction;

  @override
  State<ScanQrCodePage> createState() => _ScanQrCodePageState();
}

class _ScanQrCodePageState extends State<ScanQrCodePage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasDetectedCode = false;

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_hasDetectedCode) {
      return;
    }

    final String? rawValue = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (rawValue == null || rawValue.isEmpty) {
      return;
    }

    _hasDetectedCode = true;
    await _controller.stop();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(rawValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? l10n = AppLocalizations.of(context);
    final String title = widget.title ?? (l10n?.scanQrTitle ?? 'Scan QR Code');
    final String instruction =
        widget.instruction ??
        (l10n?.scanQrInstruction ??
            'Scan the manager\'s organization QR code to fill the API URL.');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetection,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black54,
              padding: const EdgeInsets.all(16),
              child: Text(
                instruction,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}