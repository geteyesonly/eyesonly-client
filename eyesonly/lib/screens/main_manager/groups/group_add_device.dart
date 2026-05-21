import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:eyesonly/l10n/app_localizations.dart';

import 'package:eyesonly/screens/scan_qr_code_page.dart';
import 'package:eyesonly/services/api_exception.dart';
import 'package:eyesonly/services/manager/api_service.dart';
import 'package:eyesonly/services/manager/device_registration_service.dart';
import 'package:eyesonly/services/screen_feedback.dart';

class GroupAddDevicePage extends StatefulWidget {
  const GroupAddDevicePage({
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
  State<GroupAddDevicePage> createState() => _GroupAddDevicePageState();
}

class _GroupAddDevicePageState extends State<GroupAddDevicePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final DeviceRegistrationService _deviceRegistrationService =
      DeviceRegistrationService();

  bool _isSubmitting = false;
  _ScannedJoinRequest? _scannedJoinRequest;

  AppLocalizations? get _l10n => AppLocalizations.of(context);

  bool get _hasDeviceData => _scannedJoinRequest != null;

  Future<void> _openScanDevicePage() async {
    final String? rawValue = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (BuildContext context) => ScanQrCodePage(
          title: _l10n?.groupAddScanDeviceTitle ?? 'Scan Device',
          instruction: _l10n?.groupAddScanDeviceInstruction ??
              'Scan the device QR code to capture its installation identifier and public key.',
        ),
      ),
    );

    if (!mounted || rawValue == null) {
      return;
    }

    try {
      final _ScannedJoinRequest request = _ScannedJoinRequest.fromQrPayload(
        rawValue: rawValue,
        l10n: _l10n,
      );
      final String scannedBaseUrl = request.apiUrl.trim();
      final String currentBaseUrl = widget.baseUrl.trim();
      if (scannedBaseUrl != currentBaseUrl) {
        final bool? proceed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(
              _l10n?.groupAddServerUrlMismatchTitle ?? 'Server URL mismatch',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _l10n?.groupAddServerUrlMismatchBody ??
                      'The scanned device is registered to a different server address than the one you are currently managing. This may be normal if the same server is reachable at multiple addresses (e.g. emulator vs. physical device on the same network).',
                ),
                const SizedBox(height: 16),
                Text(
                  _l10n?.groupAddCurrentServerLabel ?? 'Current server:',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(currentBaseUrl, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Text(
                  _l10n?.groupAddDeviceServerLabel ?? 'Device server:',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(scannedBaseUrl, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                Text(
                  _l10n?.groupAddServerUrlMismatchWarning ??
                      'Only continue if you are sure both addresses point to the same server.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(_l10n?.groupAddCancel ?? 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(_l10n?.groupAddAddAnyway ?? 'Add anyway'),
              ),
            ],
          ),
        );
        if (proceed != true) {
          return;
        }
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
    final _ScannedJoinRequest? scannedJoinRequest = _scannedJoinRequest;
    if (scannedJoinRequest == null) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final ManagerApiService managerApiService = ManagerApiService(
        baseUrl: widget.baseUrl,
      );
      await managerApiService.hydrateTokens();
      final DeviceRegistrationData registrationData =
          await _deviceRegistrationService.createRegistrationDataFromExistingDevice(
        deviceIdentifier: scannedJoinRequest.deviceIdentifier,
        ownerName: _nameController.text.trim(),
        publicKey: scannedJoinRequest.publicKey,
        publicKeyAlgorithm: scannedJoinRequest.publicKeyAlgorithm,
      );

      await _deviceRegistrationService.registerManagedDevice(
        managerApiService: managerApiService,
        registrationData: registrationData,
        groupId: widget.groupId,
      );

      if (!mounted) {
        return;
      }

      ScreenFeedback.showMessage(
        context,
        _l10n?.groupAddAddedMember(_nameController.text.trim(), widget.groupName) ??
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

  Widget _buildRequirementRow({
    required BuildContext context,
    required String label,
    required bool isComplete,
    String? details,
  }) {
    final AppLocalizations? l10n = _l10n;
    final Color color = isComplete
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    final IconData icon = isComplete ? Icons.check_circle : Icons.error_outline;
    final String statusText = isComplete
      ? (l10n?.groupAddStatusReady ?? 'Ready')
      : (l10n?.groupAddStatusRequired ?? 'Required');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(statusText, style: TextStyle(color: color)),
                if (details != null && details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(details, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _ScannedJoinRequest? scannedJoinRequest = _scannedJoinRequest;
    final AppLocalizations? l10n = _l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.groupAddDeviceTitle ?? 'Add Device')),
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
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n?.groupAddNameLabel ?? 'Name',
                  hintText: l10n?.groupAddNameHint ?? 'Enter a name for this device',
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n?.groupAddNameRequired ?? 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _buildRequirementRow(
                context: context,
                label: l10n?.groupAddDeviceLabel ?? 'Device',
                isComplete: scannedJoinRequest != null,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _openScanDevicePage,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(l10n?.groupAddScanDeviceAction ?? 'Scan Device'),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSubmitting || !_hasDeviceData ? null : _submit,
                child: Text(
                  _isSubmitting
                      ? (l10n?.groupAddAddingDevice ?? 'Adding Device...')
                      : (l10n?.groupAddDeviceAction ?? 'Add Device'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannedJoinRequest {
  const _ScannedJoinRequest({
    required this.apiUrl,
    required this.deviceIdentifier,
    required this.publicKey,
    required this.publicKeyAlgorithm,
  });

  final String apiUrl;
  final String deviceIdentifier;
  final String publicKey;
  final String publicKeyAlgorithm;

  factory _ScannedJoinRequest.fromQrPayload({
    required String rawValue,
    AppLocalizations? l10n,
  }) {
    final dynamic decoded = jsonDecode(rawValue);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        l10n?.scanQrInvalidJson ??
            'The scanned QR code did not contain valid JSON data.',
      );
    }

    final String type = (decoded['type'] as String?)?.trim() ?? '';
    if (type != 'eyesonly-device-join') {
      throw ApiException(
        l10n?.groupAddNotJoinCode ??
            'The scanned QR code is not a device join code.',
      );
    }

    final String apiUrl = (decoded['api_url'] as String?)?.trim() ?? '';
    final dynamic managerScopeRequests = decoded['manager_scope_requests'];
    if (managerScopeRequests is! Map<String, dynamic>) {
      throw ApiException(
        l10n?.groupAddMissingManagerRequestData ??
            'The scanned QR code is missing manager request data.',
      );
    }
    final dynamic registerDevice = managerScopeRequests['register_device'];
    if (registerDevice is! Map<String, dynamic>) {
      throw ApiException(
        l10n?.groupAddMissingRegisterData ??
            'The scanned QR code is missing register-device data.',
      );
    }

    final String deviceIdentifier =
        (registerDevice['device_identifier'] as String?)?.trim() ?? '';
    final String publicKey = (registerDevice['public_key'] as String?)?.trim() ?? '';
    final String publicKeyAlgorithm =
        (registerDevice['public_key_algorithm'] as String?)?.trim() ?? '';

    if (apiUrl.isEmpty ||
        deviceIdentifier.isEmpty ||
        publicKey.isEmpty ||
        publicKeyAlgorithm.isEmpty) {
      throw ApiException(
        l10n?.groupAddMissingRequiredData ??
            'The scanned QR code is missing required device data.',
      );
    }

    return _ScannedJoinRequest(
      apiUrl: apiUrl,
      deviceIdentifier: deviceIdentifier,
      publicKey: publicKey,
      publicKeyAlgorithm: publicKeyAlgorithm,
    );
  }
}
