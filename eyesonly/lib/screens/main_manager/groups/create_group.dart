import 'package:flutter/material.dart';

import 'package:eyesonly/l10n/app_localizations.dart';
import 'package:eyesonly/services/api_exception.dart';
import 'package:eyesonly/services/crypto/eyes_only_crypto.dart';
import 'package:eyesonly/services/installation_id_store.dart';
import 'package:eyesonly/services/manager/api_service.dart';
import 'package:eyesonly/services/manager/group_content_key_store.dart';
import 'package:eyesonly/services/manager/device_registration_service.dart';
import 'package:eyesonly/services/manager/group_name_cipher.dart';
import 'package:eyesonly/services/manager/group_scoped_metadata_cipher.dart';
import 'package:eyesonly/services/screen_feedback.dart';
import 'package:eyesonly/services/settings_store.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({
    super.key,
    required this.baseUrl,
  });

  final String baseUrl;

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final GroupContentKeyStore _groupContentKeyStore = GroupContentKeyStore();
  late final GroupScopedMetadataCipher _groupScopedMetadataCipher;
  final DeviceRegistrationService _deviceRegistrationService =
      DeviceRegistrationService();
  final SettingsStore _settingsStore = SettingsStore();

  bool _isSubmitting = false;

  AppLocalizations? get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _groupScopedMetadataCipher = GroupScopedMetadataCipher(
      groupContentKeyStore: _groupContentKeyStore,
    );
  }

  /// Polls until the creator device appears in the manager-scoped device list,
  /// then returns ALL manager-owned devices in the group (which the backend
  /// auto-adds on group creation).
  Future<List<MainManagerGroupDevice>> _waitForManagerDevicesInGroup({
    required ManagerApiService managerApiService,
    required String groupId,
    required String deviceIdentifier,
  }) async {
    const int maxAttempts = 5;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final List<MainManagerGroupDevice> devices =
          await managerApiService.getManagerGroupDevices(groupId: groupId);
      if (devices.any(
        (MainManagerGroupDevice d) => d.deviceIdentifier == deviceIdentifier,
      )) {
        return devices;
      }
      if (attempt < maxAttempts) {
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
      }
    }

    throw ApiException(
      _l10n?.createGroupCreatorNotLinkedError ??
          'Creator device was not linked to the new group.',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitCreateGroup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1. Generate content key and encrypt the group name.
      final GroupNameCipher groupNameCipher = GroupNameCipher();
      final List<int> groupSharedKeyBytes =
          await groupNameCipher.generateContentKeyBytes();
      final List<int> managerRosterKeyBytes =
          await groupNameCipher.generateContentKeyBytes();
      final ({String encryptedName, String nameNonce}) encrypted =
          await groupNameCipher.encryptGroupName(
        _nameController.text.trim(),
        groupSharedKeyBytes,
      );

      // 2. Create the group.
      final ManagerApiService managerApiService = ManagerApiService(
        baseUrl: widget.baseUrl,
      );
      await managerApiService.hydrateTokens();
      final AppSettings settings = await _settingsStore.load();
      final String username = settings.lastLoggedInUsername?.trim() ?? '';
      if (username.isEmpty) {
        throw ApiException(
          _l10n?.createGroupNoLoggedInManagerError ??
              'No logged-in manager account found for device registration.',
        );
      }
      await _deviceRegistrationService.requireCurrentDeviceRegistered(
        managerApiService: managerApiService,
      );
      final Map<String, dynamic> group = await managerApiService.createGroup(
        encryptedName: encrypted.encryptedName,
        nameNonce: encrypted.nameNonce,
        cryptoVersion: 1,
        encryptionAlgorithm: 'xchacha20poly1305',
      );

      final String groupId = (group['uuid'] as String?)?.trim() ?? '';
      if (groupId.isEmpty) {
        throw ApiException(
          _l10n?.createGroupNoUuidError ??
              'Group was created but server returned no UUID.',
          responseBody: group.toString(),
        );
      }

      // 3. The backend auto-adds ALL devices owned by this manager account
      // to the new group. Wait until the creator device appears, then fetch
      // the full list so every device gets key envelopes.
      final String deviceIdentifier =
          await InstallationIdStore().getOrCreateInstallationId();
      final List<MainManagerGroupDevice> allManagerDevices =
          await _waitForManagerDevicesInGroup(
        managerApiService: managerApiService,
        groupId: groupId,
        deviceIdentifier: deviceIdentifier,
      );

      // Save keys locally before using them to encrypt envelopes.
      await _groupContentKeyStore.saveGroupContentKey(
        groupId,
        groupSharedKeyBytes,
        scope: groupKeyScopeGroupShared,
      );
      await _groupContentKeyStore.saveGroupContentKey(
        groupId,
        managerRosterKeyBytes,
        scope: groupKeyScopeManagerRoster,
      );

      // 4. For every auto-added device: set encrypted_member_name and
      // build key envelopes for both scopes.
      final List<Map<String, dynamic>> sharedEnvelopes =
          <Map<String, dynamic>>[];
      final List<Map<String, dynamic>> rosterEnvelopes =
          <Map<String, dynamic>>[];

      for (final MainManagerGroupDevice device in allManagerDevices) {
        final String encryptedMemberName = await _groupScopedMetadataCipher
            .encryptForGroup(
              groupId: groupId,
              scope: groupKeyScopeManagerRoster,
              plaintext: username,
            );
        await managerApiService.addDeviceToGroup(
          deviceIdentifier: device.deviceIdentifier,
          groupId: groupId,
          encryptedMemberName: encryptedMemberName,
        );

        final String encryptedSharedKey = await EyesOnlyCrypto.wrapForPublicKey(
          groupSharedKeyBytes,
          device.publicKey,
          groupKeyEncryptionHkdfInfo,
        );
        sharedEnvelopes.add(<String, dynamic>{
          'recipient_device_identifier': device.deviceIdentifier,
          'key_wrap_algorithm': 'x25519-hkdf-xchacha20poly1305',
          'recipient_key_fingerprint': device.publicKeyFingerprint,
          'encrypted_group_key': encryptedSharedKey,
        });

        final String encryptedRosterKey = await EyesOnlyCrypto.wrapForPublicKey(
          managerRosterKeyBytes,
          device.publicKey,
          groupKeyEncryptionHkdfInfo,
        );
        rosterEnvelopes.add(<String, dynamic>{
          'recipient_device_identifier': device.deviceIdentifier,
          'key_wrap_algorithm': 'x25519-hkdf-xchacha20poly1305',
          'recipient_key_fingerprint': device.publicKeyFingerprint,
          'encrypted_group_key': encryptedRosterKey,
        });
      }

      await managerApiService.createGroupKeyEnvelope(
        groupId: groupId,
        scope: groupKeyScopeGroupShared,
        keyEnvelopes: sharedEnvelopes,
      );

      await managerApiService.createGroupKeyEnvelope(
        groupId: groupId,
        scope: groupKeyScopeManagerRoster,
        keyEnvelopes: rosterEnvelopes,
      );

      if (!mounted) {
        return;
      }

      ScreenFeedback.showMessage(
        context,
        _l10n?.createGroupSuccess ?? 'Group created successfully.',
      );
      Navigator.pop(context, true);
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
    final AppLocalizations? l10n = _l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.createGroupTitle ?? 'Create Group')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n?.createGroupHeading ?? 'New Group',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n?.createGroupNameLabel ?? 'Name',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n?.createGroupNameRequired ??
                              'Name is required';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submitCreateGroup(),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submitCreateGroup,
                      child: Text(
                        _isSubmitting
                            ? (l10n?.createGroupCreating ?? 'Creating...')
                            : (l10n?.createGroupTitle ?? 'Create Group'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
