import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:eyesonly/services/manager/auth_token_store.dart';
import 'package:eyesonly/services/manager/device_registration_service.dart';

class JoinGroupQrPage extends StatefulWidget {
  const JoinGroupQrPage({
    super.key,
    required this.organizationName,
    required this.apiUrl,
  });

  final String organizationName;
  final String apiUrl;

  @override
  State<JoinGroupQrPage> createState() => _JoinGroupQrPageState();
}

class _JoinGroupQrPageState extends State<JoinGroupQrPage> {
  final DeviceRegistrationService _deviceRegistrationService =
      DeviceRegistrationService();

  bool _isLoading = true;
  String? _errorMessage;
  String? _qrPayload;
  String? _installationId;

  @override
  void initState() {
    super.initState();
    _loadQrPayload();
  }

  Future<void> _loadQrPayload() async {
    try {
      final DeviceJoinRequestData joinRequestData =
          await _deviceRegistrationService.getOrCreateJoinRequestData();

      // Include the manager user ID when this device is logged in as a manager.
      // This allows a main manager scanning the QR to register this device
      // under the correct manager account.
      final String? accessToken = await AuthTokenStore().readAccessToken();
      final int? ownerUserId =
          DeviceRegistrationService.extractUserIdFromJwt(accessToken);

      final String qrPayload = jsonEncode(<String, dynamic>{
        'type': 'eyesonly-device-join',
        'version': 1,
        'api_url': widget.apiUrl,
        'owner_user_id': ownerUserId,
        'manager_scope_requests': <String, dynamic>{
          'register_device': <String, dynamic>{
            'device_identifier': joinRequestData.deviceIdentifier,
            'public_key': joinRequestData.publicKey,
            'public_key_algorithm': joinRequestData.publicKeyAlgorithm,
          },
          'add_device_to_group': <String, dynamic>{
            'device_identifier': joinRequestData.deviceIdentifier,
            // The main manager must choose the target group after scanning.
            'group': null,
          },
        },
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _installationId = joinRequestData.deviceIdentifier;
        _qrPayload = qrPayload;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Group')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _isLoading
                ? const CircularProgressIndicator()
                : _errorMessage != null
                    ? Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.organizationName,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          QrImageView(
                            data: _qrPayload!,
                            version: QrVersions.auto,
                            size: 280,
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Have a main manager scan this QR code and choose the group.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Card(
                              child: ExpansionTile(
                                title: const Text('What is shared?'),
                                childrenPadding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                children: [
                                  Text(
                                    'This QR code shares the organization server URL, this installation identifier, and this device public key data so a main manager can register the device and add it to a selected group.',
                                    textAlign: TextAlign.left,
                                  ),
                                  if (_installationId != null) ...[
                                    const SizedBox(height: 12),
                                    SelectableText(
                                      'Installation Identifier: $_installationId',
                                      textAlign: TextAlign.left,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }
}