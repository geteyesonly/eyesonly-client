import 'package:flutter/material.dart';
import 'package:eyesonly/l10n/app_localizations.dart';

import 'package:eyesonly/screens/main_manager/groups/group_push_notification_page.dart';
import 'package:eyesonly/screens/main_manager/groups/group_add_device.dart';
import 'package:eyesonly/screens/main_manager/groups/group_add_manager_device.dart';
import 'package:eyesonly/services/api_exception.dart';
import 'package:eyesonly/services/device/api_service.dart';
import 'package:eyesonly/services/group_display_service.dart';
import 'package:eyesonly/services/manager/api_service.dart';
import 'package:eyesonly/services/manager/group_content_key_store.dart';
import 'package:eyesonly/services/manager/group_name_cipher.dart';
import 'package:eyesonly/services/manager/group_notification_service.dart';
import 'package:eyesonly/services/screen_feedback.dart';

class GroupDetailPage extends StatefulWidget {
  const GroupDetailPage({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.baseUrl,
    required this.organizationName,
    required this.isManager,
    this.groupDisplayService,
    this.managerApiService,
    this.deviceApiService,
    this.groupNotificationService,
  });

  final String groupId;
  final String groupName;
  final String baseUrl;
  final String organizationName;
  final bool isManager;
  final GroupDisplayService? groupDisplayService;
  final ManagerApiService? managerApiService;
  final DeviceApiService? deviceApiService;
  final GroupNotificationService? groupNotificationService;

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  bool _isLoading = true;
  bool _showDeviceIdentifiers = false;
  bool _isLeaving = false;
  bool _isDeletingGroup = false;
  bool _isRenamingGroup = false;
  bool _didChangeGroup = false;
  String? _errorMessage;
  late String _groupName;
  late final GroupDisplayService _groupDisplayService;
  late final ManagerApiService _managerApiService;
  late final DeviceApiService _deviceApiService;
  late final GroupNotificationService _groupNotificationService;
  final GroupContentKeyStore _groupContentKeyStore = GroupContentKeyStore();
  final Set<String> _removingDeviceIds = <String>{};
  List<_DeviceListEntry> _devices = <_DeviceListEntry>[];

  AppLocalizations? get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _groupName = widget.groupName;
    _groupDisplayService = widget.groupDisplayService ?? GroupDisplayService();
    _managerApiService =
        widget.managerApiService ?? ManagerApiService(baseUrl: widget.baseUrl);
    _deviceApiService =
        widget.deviceApiService ?? DeviceApiService(baseUrl: widget.baseUrl);
    _groupNotificationService =
        widget.groupNotificationService ??
        GroupNotificationService(
          managerApiService: _managerApiService,
          groupDisplayService: _groupDisplayService,
        );
    if (widget.isManager) {
      _loadDevices();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _managerApiService.hydrateTokens();
      await _groupDisplayService.syncGroupKeysFromDeviceEndpoint(
        baseUrl: widget.baseUrl,
        groupIds: <String>[widget.groupId],
        scopes: const <String>[groupKeyScopeManagerRoster],
      );
      final List<MainManagerGroupDevice> devices = await _managerApiService
          .getMainManagerGroupDevices(groupId: widget.groupId);
      final List<_DeviceListEntry> entries = <_DeviceListEntry>[];
      for (final MainManagerGroupDevice device in devices) {
        String ownerName =
            _l10n?.groupDetailDecryptionFailed ?? 'Decryption failed';
        final String? decryptedOwnerName = await _groupDisplayService
            .tryDecryptMemberName(
              groupId: widget.groupId,
              encryptedMemberName: device.encryptedMemberName ?? '',
            );
        if (decryptedOwnerName?.trim().isNotEmpty ?? false) {
          ownerName = decryptedOwnerName!.trim();
        }
        entries.add(
          _DeviceListEntry(
            ownerName: ownerName,
            deviceIdentifier: device.deviceIdentifier,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _devices = entries;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            _l10n?.unexpectedErrorOccurred ?? 'An unexpected error occurred.';
        _isLoading = false;
      });
    }
  }

  Future<void> _removeDevice(_DeviceListEntry device) async {
    setState(() => _removingDeviceIds.add(device.deviceIdentifier));

    try {
      await _managerApiService.hydrateTokens();
      await _managerApiService.removeDeviceFromGroup(
        deviceIdentifier: device.deviceIdentifier,
        groupId: widget.groupId,
      );

      if (!mounted) return;
      setState(() {
        _devices = _devices
            .where((e) => e.deviceIdentifier != device.deviceIdentifier)
            .toList();
      });
      ScreenFeedback.showMessage(
        context,
        _l10n?.groupDetailRemovedFromGroup(device.ownerName) ??
            'Removed ${device.ownerName} from the group.',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScreenFeedback.showError(context, error);
    } catch (error) {
      if (!mounted) return;
      ScreenFeedback.showError(context, error);
    } finally {
      if (mounted) {
        setState(() => _removingDeviceIds.remove(device.deviceIdentifier));
      }
    }
  }

  Future<void> _confirmRemoveDevice(_DeviceListEntry device) async {
    final bool? shouldRemove = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_l10n?.groupDetailRemoveDeviceTitle ?? 'Remove Device?'),
          content: Text(
            _l10n?.groupDetailRemoveDevicePrompt(device.ownerName) ??
                'Remove ${device.ownerName} from this group?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_l10n?.groupDetailCancel ?? 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(_l10n?.groupDetailRemoveAction ?? 'Remove'),
            ),
          ],
        );
      },
    );
    if (shouldRemove == true) {
      await _removeDevice(device);
    }
  }

  Future<void> _deleteGroup() async {
    setState(() => _isDeletingGroup = true);
    try {
      await _managerApiService.hydrateTokens();
      await _managerApiService.deleteGroup(groupId: widget.groupId);

      if (!mounted) return;
      Navigator.of(context).pop(true); // return to groups overview and refresh
    } on ApiException catch (error) {
      if (!mounted) return;
      ScreenFeedback.showError(context, error);
    } catch (error) {
      if (!mounted) return;
      ScreenFeedback.showError(context, error);
    } finally {
      if (mounted) {
        setState(() => _isDeletingGroup = false);
      }
    }
  }

  Future<void> _confirmDeleteGroup() async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_l10n?.groupDetailDeleteGroupTitle ?? 'Delete Group?'),
          content: Text(
            _l10n?.groupDetailDeleteGroupPrompt(_groupName) ??
                'Do you really want to delete $_groupName?\n\nThis action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_l10n?.groupDetailCancel ?? 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: Text(
                _l10n?.groupDetailDeleteGroupAction ?? 'Delete Group',
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await _deleteGroup();
    }
  }

  Future<void> _leaveGroup() async {
    setState(() => _isLeaving = true);
    try {
      await _deviceApiService.leaveGroup(groupId: widget.groupId);
      if (!mounted) return;
      Navigator.of(context).pop(true); // signal groups page to refresh
    } on ApiException catch (error) {
      if (!mounted) return;
      ScreenFeedback.showError(context, error);
    } catch (error) {
      if (!mounted) return;
      ScreenFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }

  Future<void> _confirmLeaveGroup() async {
    final bool? shouldLeave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_l10n?.groupDetailLeaveGroupTitle ?? 'Leave Group?'),
          content: Text(
            _l10n?.groupDetailLeaveGroupPrompt(_groupName) ??
                'Do you really want to leave $_groupName?\n\nOnly a manager can re-add you to this group.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_l10n?.groupDetailCancel ?? 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(_l10n?.groupDetailLeaveAction ?? 'Leave'),
            ),
          ],
        );
      },
    );
    if (shouldLeave == true) {
      await _leaveGroup();
    }
  }

  Future<void> _openGroupNotificationPage() async {
    final GroupNotificationResult? result = await Navigator.of(context)
        .push<GroupNotificationResult>(
          MaterialPageRoute<GroupNotificationResult>(
            builder: (BuildContext context) => GroupPushNotificationPage(
              groupId: widget.groupId,
              groupName: _groupName,
              baseUrl: widget.baseUrl,
              groupNotificationService: _groupNotificationService,
            ),
          ),
        );
    if (!mounted || result == null) {
      return;
    }

    final String message = result.skippedCount > 0
        ? (_l10n?.groupDetailNotificationSentSkipped(
                result.notifiedCount,
                result.skippedCount,
              ) ??
              'Notification sent to ${result.notifiedCount} devices. ${result.skippedCount} were skipped.')
        : (_l10n?.groupDetailNotificationSent(result.notifiedCount) ??
              'Notification sent to ${result.notifiedCount} devices.');
    ScreenFeedback.showMessage(context, message);
  }

  Future<void> _promptRenameGroup() async {
    final TextEditingController nameController = TextEditingController(
      text: _groupName,
    );

    try {
      final String? submittedName = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(_l10n?.groupDetailRenameGroupTitle ?? 'Rename group'),
            content: TextField(
              controller: nameController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (String _) {
                final String normalized = nameController.text.trim();
                if (normalized.isNotEmpty) {
                  Navigator.of(context).pop(normalized);
                }
              },
              decoration: InputDecoration(
                labelText: _l10n?.groupDetailGroupNameLabel ?? 'Group name',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(_l10n?.groupDetailCancel ?? 'Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final String normalized = nameController.text.trim();
                  if (normalized.isEmpty) {
                    return;
                  }
                  Navigator.of(context).pop(normalized);
                },
                child: Text(_l10n?.groupDetailSaveAction ?? 'Save'),
              ),
            ],
          );
        },
      );

      if (submittedName == null) {
        return;
      }

      final String normalizedNewName = submittedName.trim();
      if (normalizedNewName.isEmpty || normalizedNewName == _groupName) {
        return;
      }

      await _renameGroup(normalizedNewName);
    } finally {
      nameController.dispose();
    }
  }

  Future<void> _renameGroup(String newName) async {
    setState(() => _isRenamingGroup = true);

    try {
      await _managerApiService.hydrateTokens();
      await _groupDisplayService.syncGroupKeysFromDeviceEndpoint(
        baseUrl: widget.baseUrl,
        groupIds: <String>[widget.groupId],
        scopes: const <String>[groupKeyScopeGroupShared],
      );

      final List<int>? groupSharedKey = await _groupContentKeyStore
          .readGroupContentKey(widget.groupId, scope: groupKeyScopeGroupShared);
      if (groupSharedKey == null) {
        throw ApiException(
          'Required group encryption key is not available on this device.',
        );
      }

      final GroupNameCipher groupNameCipher = GroupNameCipher();
      final ({String encryptedName, String nameNonce}) encrypted =
          await groupNameCipher.encryptGroupName(newName, groupSharedKey);

      await _managerApiService.updateGroup(
        groupId: widget.groupId,
        encryptedName: encrypted.encryptedName,
        nameNonce: encrypted.nameNonce,
        cryptoVersion: 1,
        encryptionAlgorithm: 'xchacha20poly1305',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _groupName = newName;
        _didChangeGroup = true;
      });
      ScreenFeedback.showMessage(
        context,
        _l10n?.groupDetailRenamed ?? 'Group renamed.',
      );
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
        setState(() => _isRenamingGroup = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? l10n = _l10n;

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_didChangeGroup ? true : null);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_groupName),
          actions: [
            if (widget.isManager)
              IconButton(
                onPressed: _isLoading || _isRenamingGroup
                    ? null
                    : _promptRenameGroup,
                icon: const Icon(Icons.edit),
                tooltip:
                    l10n?.groupDetailEditGroupNameTooltip ?? 'Edit group name',
              ),
          ],
        ),
        floatingActionButton: widget.isManager
            ? FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push<bool>(
                    context,
                    MaterialPageRoute<bool>(
                      builder: (BuildContext context) => GroupAddDevicePage(
                        groupId: widget.groupId,
                        groupName: _groupName,
                        baseUrl: widget.baseUrl,
                        organizationName: widget.organizationName,
                      ),
                    ),
                  ).then((bool? added) {
                    if (added == true) {
                      _loadDevices();
                    }
                  });
                },
                icon: const Icon(Icons.add),
                label: Text(l10n?.groupDetailAddMember ?? 'Add Member'),
              )
            : null,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.isManager) ...[
                      FilledButton.icon(
                        onPressed: _isLeaving ? null : _confirmLeaveGroup,
                        icon: _isLeaving
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.exit_to_app),
                        label: Text(l10n?.groupsLeaveGroup ?? 'Leave Group'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onError,
                        ),
                      ),
                    ] else ...[
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l10n?.groupDetailShowInstallationIdentifiers ??
                              'Show installation identifiers',
                        ),
                        value: _showDeviceIdentifiers,
                        onChanged: (bool value) {
                          setState(() => _showDeviceIdentifiers = value);
                        },
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push<bool>(
                              context,
                              MaterialPageRoute<bool>(
                                builder: (BuildContext context) =>
                                    GroupAddManagerDevicePage(
                                      groupId: widget.groupId,
                                      groupName: _groupName,
                                      baseUrl: widget.baseUrl,
                                      organizationName: widget.organizationName,
                                    ),
                              ),
                            ).then((bool? added) {
                              if (added == true) {
                                _loadDevices();
                              }
                            });
                          },
                          icon: const Icon(Icons.manage_accounts),
                          label: Text(
                            l10n?.groupAddManagerDeviceTitle ??
                                'Add Manager Device',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _openGroupNotificationPage,
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: Text(
                            l10n?.homeSendMessageToGroup ??
                                'Send Message to Group',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _errorMessage != null
                            ? ListView(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Text(_errorMessage!),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: FilledButton.icon(
                                      onPressed: _isDeletingGroup
                                          ? null
                                          : _confirmDeleteGroup,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                        foregroundColor: Theme.of(
                                          context,
                                        ).colorScheme.onError,
                                      ),
                                      icon: _isDeletingGroup
                                          ? const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.delete_forever_outlined,
                                            ),
                                      label: Text(
                                        l10n?.groupDetailDeleteGroupAction ??
                                            'Delete Group',
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : _devices.isEmpty
                            ? ListView(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      l10n?.groupDetailNoDevicesInGroup ??
                                          'No devices in this group.',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: FilledButton.icon(
                                      onPressed: _isDeletingGroup
                                          ? null
                                          : _confirmDeleteGroup,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                        foregroundColor: Theme.of(
                                          context,
                                        ).colorScheme.onError,
                                      ),
                                      icon: _isDeletingGroup
                                          ? const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.delete_forever_outlined,
                                            ),
                                      label: Text(
                                        l10n?.groupDetailDeleteGroupAction ??
                                            'Delete Group',
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                itemCount: _devices.length + 1,
                                separatorBuilder: (_, int index) =>
                                    index < _devices.length - 1
                                    ? const Divider(height: 1)
                                    : const SizedBox(height: 12),
                                itemBuilder: (BuildContext context, int index) {
                                  if (index == _devices.length) {
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: FilledButton.icon(
                                        onPressed: _isDeletingGroup
                                            ? null
                                            : _confirmDeleteGroup,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                          foregroundColor: Theme.of(
                                            context,
                                          ).colorScheme.onError,
                                        ),
                                        icon: _isDeletingGroup
                                            ? const SizedBox(
                                                height: 16,
                                                width: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.delete_forever_outlined,
                                              ),
                                        label: Text(
                                          l10n?.groupDetailDeleteGroupAction ??
                                              'Delete Group',
                                        ),
                                      ),
                                    );
                                  }

                                  final _DeviceListEntry device =
                                      _devices[index];
                                  return ListTile(
                                    leading: const Icon(Icons.devices_outlined),
                                    title: Text(device.ownerName),
                                    subtitle: _showDeviceIdentifiers
                                        ? Text(device.deviceIdentifier)
                                        : null,
                                    trailing: TextButton(
                                      onPressed:
                                          _removingDeviceIds.contains(
                                            device.deviceIdentifier,
                                          )
                                          ? null
                                          : () => _confirmRemoveDevice(device),
                                      child:
                                          _removingDeviceIds.contains(
                                            device.deviceIdentifier,
                                          )
                                          ? const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              l10n?.groupDetailRemoveAction ??
                                                  'Remove',
                                            ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _DeviceListEntry {
  const _DeviceListEntry({
    required this.ownerName,
    required this.deviceIdentifier,
  });

  final String ownerName;
  final String deviceIdentifier;
}
