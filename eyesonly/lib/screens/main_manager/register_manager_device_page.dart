import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:eyesonly/screens/scan_qr_code_page.dart';
import 'package:eyesonly/services/api_exception.dart';
import 'package:eyesonly/services/manager/api_service.dart';
import 'package:eyesonly/services/manager/device_registration_service.dart';
import 'package:eyesonly/services/screen_feedback.dart';

class RegisterManagerDevicePage extends StatefulWidget {
  const RegisterManagerDevicePage({
    super.key,
    required this.baseUrl,
    required this.organizationName,
  });

  final String baseUrl;
  final String organizationName;

  @override
  State<RegisterManagerDevicePage> createState() =>
      _RegisterManagerDevicePageState();
}

class _RegisterManagerDevicePageState
    extends State<RegisterManagerDevicePage> {
  final DeviceRegistrationService _deviceRegistrationService =
      DeviceRegistrationService();

  bool _isSubmitting = false;
  _ScannedManagerDevice? _scannedDevice;

  bool get _hasDeviceData => _scannedDevice != null;

  Future<void> _openScanDevicePage() async {
    final String? rawValue = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (BuildContext context) => const ScanQrCodePage(
          title: 'Scan Manager Device',
          instruction:
              'On the second device, go to Groups → Join Group and scan that QR code here.',
        ),
      ),
    );

    if (!mounted || rawValue == null) {
      return;
    }

    try {
      final _ScannedManagerDevice device = _ScannedManagerDevice.fromQrPayload(
        rawValue: rawValue,
      );
      final String scannedBaseUrl = device.apiUrl.trim();
      final String currentBaseUrl = widget.baseUrl.trim();
      if (scannedBaseUrl != currentBaseUrl) {
        final bool? proceed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Server URL mismatch'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The scanned device is registered to a different server address. This may be normal if both addresses point to the same server (e.g. emulator vs. physical device on the same network).',
                ),
                const SizedBox(height: 16),
                Text('Current server:', style: Theme.of(context).textTheme.labelSmall),
                Text(currentBaseUrl, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Text('Device server:', style: Theme.of(context).textTheme.labelSmall),
                Text(scannedBaseUrl, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                const Text('Only continue if you are sure both addresses point to the same server.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        if (proceed != true) {
          return;
        }
      }

      setState(() {
        _scannedDevice = device;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScreenFeedback.showError(context, error);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScreenFeedback.showError(context, error);
    }
  }

  Future<void> _submit() async {
    final _ScannedManagerDevice? scannedDevice = _scannedDevice;
    if (scannedDevice == null) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final ManagerApiService managerApiService =
          ManagerApiService(baseUrl: widget.baseUrl);
      await managerApiService.hydrateTokens();

      final DeviceRegistrationData registrationData =
          await _deviceRegistrationService
              .createRegistrationDataFromExistingDevice(
        deviceIdentifier: scannedDevice.deviceIdentifier,
        ownerName: '',
        publicKey: scannedDevice.publicKey,
        publicKeyAlgorithm: scannedDevice.publicKeyAlgorithm,
      );

      await _deviceRegistrationService.registerManagerDeviceAndProvisionKeys(
        managerApiService: managerApiService,
        registrationData: registrationData,
      );

      if (!mounted) {
        return;
      }

      ScreenFeedback.showMessage(context, 'Device registered successfully.');
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScreenFeedback.showError(context, error);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScreenFeedback.showError(context, error);
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
    final _ScannedManagerDevice? scannedDevice = _scannedDevice;

    return Scaffold(
      appBar: AppBar(title: const Text('Register Manager Device')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.organizationName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Scan the QR code shown on the second manager device (Groups → Join Group) to register it as an additional device for your account.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Row(
                children: [
                  Icon(
                    scannedDevice != null
                        ? Icons.check_circle
                        : Icons.error_outline,
                    color: scannedDevice != null
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    scannedDevice != null ? 'Device scanned' : 'Scan required',
                    style: TextStyle(
                      color: scannedDevice != null
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _openScanDevicePage,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan Device QR'),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting || !_hasDeviceData ? null : _submit,
              child: Text(
                _isSubmitting ? 'Registering...' : 'Register Device',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannedManagerDevice {
  const _ScannedManagerDevice({
    required this.apiUrl,
    required this.deviceIdentifier,
    required this.publicKey,
    required this.publicKeyAlgorithm,
  });

  final String apiUrl;
  final String deviceIdentifier;
  final String publicKey;
  final String publicKeyAlgorithm;

  factory _ScannedManagerDevice.fromQrPayload({required String rawValue}) {
    final dynamic decoded = jsonDecode(rawValue);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('The scanned QR code did not contain valid JSON data.');
    }

    final String type = (decoded['type'] as String?)?.trim() ?? '';
    if (type != 'eyesonly-device-join') {
      throw ApiException('The scanned QR code is not a device join code.');
    }

    final String apiUrl = (decoded['api_url'] as String?)?.trim() ?? '';

    final dynamic managerScopeRequests = decoded['manager_scope_requests'];
    if (managerScopeRequests is! Map<String, dynamic>) {
      throw ApiException(
        'The scanned QR code is missing manager request data.',
      );
    }

    final dynamic registerDeviceData = managerScopeRequests['register_device'];
    if (registerDeviceData is! Map<String, dynamic>) {
      throw ApiException(
        'The scanned QR code is missing register-device data.',
      );
    }

    final String deviceIdentifier =
        (registerDeviceData['device_identifier'] as String?)?.trim() ?? '';
    final String publicKey =
        (registerDeviceData['public_key'] as String?)?.trim() ?? '';
    final String publicKeyAlgorithm =
        (registerDeviceData['public_key_algorithm'] as String?)?.trim() ??
        'x25519';

    if (deviceIdentifier.isEmpty || publicKey.isEmpty) {
      throw ApiException(
        'The scanned QR code is missing required device data.',
      );
    }

    return _ScannedManagerDevice(
      apiUrl: apiUrl,
      deviceIdentifier: deviceIdentifier,
      publicKey: publicKey,
      publicKeyAlgorithm: publicKeyAlgorithm,
    );
  }
}
