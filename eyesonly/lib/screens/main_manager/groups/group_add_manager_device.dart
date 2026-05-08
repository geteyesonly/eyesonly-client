import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:eyesonly/screens/scan_qr_code_page.dart';
import 'package:eyesonly/services/api_exception.dart';
import 'package:eyesonly/services/manager/api_service.dart';
import 'package:eyesonly/services/manager/device_registration_service.dart';
import 'package:eyesonly/services/screen_feedback.dart';

class GroupAddManagerDevicePage extends StatefulWidget {
  const GroupAddManagerDevicePage({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.baseUrl,
    required this.organizationName,
  });

  final String groupId;
  final String groupName;
  final String baseUrl;
  final String organizationName;

  @override
  State<GroupAddManagerDevicePage> createState() =>
      _GroupAddManagerDevicePageState();
}

class _GroupAddManagerDevicePageState
    extends State<GroupAddManagerDevicePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final DeviceRegistrationService _deviceRegistrationService =
      DeviceRegistrationService();

  bool _isSubmitting = false;
  _ScannedManagerJoinRequest? _scannedJoinRequest;

  bool get _hasDeviceData => _scannedJoinRequest != null;

  Future<void> _openScanDevicePage() async {
    final String? rawValue = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (BuildContext context) => const ScanQrCodePage(
          title: 'Scan Manager Device',
          instruction:
              'On the other manager\'s device, go to Groups → Join Group and scan the QR code shown there.',
        ),
      ),
    );

    if (!mounted || rawValue == null) {
      return;
    }

    try {
      final _ScannedManagerJoinRequest request =
          _ScannedManagerJoinRequest.fromQrPayload(rawValue: rawValue);

      final String scannedBaseUrl = request.apiUrl.trim();
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
                  'The scanned device reports a different server address. This may be normal if both addresses point to the same server (e.g. emulator vs. physical device).',
                ),
                const SizedBox(height: 16),
                Text('Current server:', style: Theme.of(context).textTheme.labelSmall),
                Text(currentBaseUrl, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Text('Device server:', style: Theme.of(context).textTheme.labelSmall),
                Text(scannedBaseUrl, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                const Text(
                  'Only continue if you are sure both addresses point to the same server.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Add anyway'),
              ),
            ],
          ),
        );
        if (proceed != true) {
          return;
        }
      }

      if (request.ownerUserId == 0) {
        if (mounted) {
          ScreenFeedback.showError(
            context,
            ApiException(
              'This QR code does not include a manager account. Make sure the other manager is logged in before showing the QR code.',
            ),
          );
        }
        return;
      }

      setState(() {
        _scannedJoinRequest = request;
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
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final _ScannedManagerJoinRequest? scannedJoinRequest = _scannedJoinRequest;
    if (scannedJoinRequest == null) {
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
        deviceIdentifier: scannedJoinRequest.deviceIdentifier,
        ownerName: _nameController.text.trim(),
        publicKey: scannedJoinRequest.publicKey,
        publicKeyAlgorithm: scannedJoinRequest.publicKeyAlgorithm,
      );

      await _deviceRegistrationService.addExternalManagerDeviceToGroup(
        managerApiService: managerApiService,
        registrationData: registrationData,
        groupId: widget.groupId,
        ownerUser: scannedJoinRequest.ownerUserId,
        isManager: true,
      );

      if (!mounted) {
        return;
      }

      ScreenFeedback.showMessage(
        context,
        'Added ${_nameController.text.trim()} to ${widget.groupName}.',
      );
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
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _ScannedManagerJoinRequest? scannedJoinRequest = _scannedJoinRequest;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Manager Device')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.groupName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                widget.organizationName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Scan the QR code shown on the other manager\'s device (Groups → Join Group) while they are logged in as a manager.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter a name for this device',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    scannedJoinRequest != null
                        ? Icons.check_circle
                        : Icons.error_outline,
                    color: scannedJoinRequest != null
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    scannedJoinRequest != null ? 'Device scanned' : 'Scan required',
                    style: TextStyle(
                      color: scannedJoinRequest != null
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
                  _isSubmitting ? 'Adding Device...' : 'Add Manager Device',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannedManagerJoinRequest {
  const _ScannedManagerJoinRequest({
    required this.apiUrl,
    required this.deviceIdentifier,
    required this.publicKey,
    required this.publicKeyAlgorithm,
    required this.ownerUserId,
  });

  final String apiUrl;
  final String deviceIdentifier;
  final String publicKey;
  final String publicKeyAlgorithm;
  /// The manager user ID of the device owner. 0 when not present in the QR.
  final int ownerUserId;

  factory _ScannedManagerJoinRequest.fromQrPayload({
    required String rawValue,
  }) {
    final dynamic decoded = jsonDecode(rawValue);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('The scanned QR code did not contain valid JSON data.');
    }

    final String type = (decoded['type'] as String?)?.trim() ?? '';
    if (type != 'eyesonly-device-join') {
      throw ApiException('The scanned QR code is not a device join code.');
    }

    final String apiUrl = (decoded['api_url'] as String?)?.trim() ?? '';

    final dynamic rawOwnerUserId = decoded['owner_user_id'];
    final int ownerUserId = rawOwnerUserId is int
        ? rawOwnerUserId
        : rawOwnerUserId is String
            ? int.tryParse(rawOwnerUserId.trim()) ?? 0
            : 0;

    final dynamic managerScopeRequests = decoded['manager_scope_requests'];
    if (managerScopeRequests is! Map<String, dynamic>) {
      throw ApiException('The scanned QR code is missing manager request data.');
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

    return _ScannedManagerJoinRequest(
      apiUrl: apiUrl,
      deviceIdentifier: deviceIdentifier,
      publicKey: publicKey,
      publicKeyAlgorithm: publicKeyAlgorithm,
      ownerUserId: ownerUserId,
    );
  }
}
