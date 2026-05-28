import 'package:flutter/material.dart';

import 'package:eyesonly/l10n/app_localizations.dart';
import 'package:eyesonly/screens/main_manager/capture_picture_page.dart';
import 'package:eyesonly/screens/main_manager/login_page.dart';
import 'package:eyesonly/services/api_exception.dart';
import 'package:eyesonly/services/group_display_service.dart';
import 'package:eyesonly/services/manager/api_service.dart';
import 'package:eyesonly/services/manager/device_registration_service.dart';
import 'package:eyesonly/services/settings_store.dart';

typedef CaptureGroupSelected = Future<void> Function(
  String groupId,
  String groupName,
);

class SelectCaptureGroupPage extends StatefulWidget {
  const SelectCaptureGroupPage({
    super.key,
    required this.baseUrl,
    this.groupDisplayService,
    this.deviceRegistrationService,
    this.settingsStore,
    this.managerApiService,
    this.onGroupSelected,
  });

  final String baseUrl;
  final GroupDisplayService? groupDisplayService;
  final DeviceRegistrationService? deviceRegistrationService;
  final SettingsStore? settingsStore;
  final ManagerApiService? managerApiService;
  final CaptureGroupSelected? onGroupSelected;

  @override
  State<SelectCaptureGroupPage> createState() => _SelectCaptureGroupPageState();
}

class _SelectCaptureGroupPageState extends State<SelectCaptureGroupPage> {
  late final GroupDisplayService _groupDisplayService;
  late final DeviceRegistrationService _deviceRegistrationService;
  late final SettingsStore _settingsStore;
  late final ManagerApiService _managerApiService;

  bool _isLoading = true;
  String? _errorMessage;
  List<_CaptureGroupEntry> _groups = <_CaptureGroupEntry>[];

  AppLocalizations? get _l10n => AppLocalizations.of(context);

  bool _isSessionExpiredError(ApiException error) {
    final String message = error.message.trim().toLowerCase();
    return error.statusCode == 401 ||
        message.contains('session has expired') ||
        message.contains('please log in again') ||
        message.contains('could not be authenticated with this server');
  }

  Future<void> _redirectToLoginForExpiredSession() async {
    await _settingsStore.saveLastLoggedInUsername(null);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const LoginPage(),
      ),
      (Route<dynamic> route) => route.isFirst,
    );
  }

  @override
  void initState() {
    super.initState();
    _groupDisplayService = widget.groupDisplayService ?? GroupDisplayService();
    _deviceRegistrationService =
        widget.deviceRegistrationService ?? DeviceRegistrationService();
    _settingsStore = widget.settingsStore ?? SettingsStore();
    _managerApiService =
        widget.managerApiService ?? ManagerApiService(baseUrl: widget.baseUrl);
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _settingsStore.load();
      await _managerApiService.hydrateTokens();
      await _deviceRegistrationService.requireCurrentDeviceRegistered(
        managerApiService: _managerApiService,
      );

      final List<Map<String, dynamic>> managerGroups =
          await _managerApiService.getManagerGroups();
      final List<_CaptureGroupSource> allowedGroups = managerGroups
          .map(_CaptureGroupSource.fromJson)
          .where((_CaptureGroupSource group) {
            return group.id.isNotEmpty && _canTakePicturesForRole(group.status);
          })
          .toList();

      await _groupDisplayService.syncGroupKeysFromDeviceEndpoint(
        baseUrl: widget.baseUrl,
        groupIds: allowedGroups.map((_CaptureGroupSource group) => group.id),
      );

      final List<_CaptureGroupEntry> groups = <_CaptureGroupEntry>[];
      for (final _CaptureGroupSource group in allowedGroups) {
        final String groupId = group.id.trim();
        if (groupId.isEmpty) {
          continue;
        }

        final String resolvedName = await _groupDisplayService.tryDecryptGroupName(
              groupId: groupId,
              encryptedName: group.encryptedName,
              nameNonce: group.nameNonce,
            ) ??
            (_l10n?.groupsFallbackName(groupId.substring(0, 8)) ??
                'Group ${groupId.substring(0, 8)}');

        groups.add(
          _CaptureGroupEntry(
            id: groupId,
            name: resolvedName,
          ),
        );
      }

      groups.sort(
        (_CaptureGroupEntry a, _CaptureGroupEntry b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _groups = groups;
        _isLoading = false;
      });

      // Skip selection when there is only one group.
      if (groups.length == 1 && mounted) {
        await _selectGroup(groups.first);
        if (mounted) Navigator.of(context).pop();
      }
    } on ApiException catch (error) {
      if (_isSessionExpiredError(error)) {
        await _redirectToLoginForExpiredSession();
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _l10n?.unexpectedErrorOccurred ?? 'An unexpected error occurred.';
        _isLoading = false;
      });
    }
  }

  bool _canTakePicturesForRole(String? role) {
    final String normalized = role
            ?.trim()
            .toLowerCase()
            .replaceAll('-', '_')
            .replaceAll(' ', '_') ??
        '';
    return normalized == 'manager' || normalized == 'main_manager';
  }

  Future<void> _selectGroup(_CaptureGroupEntry group) async {
    if (widget.onGroupSelected != null) {
      await widget.onGroupSelected!(group.id, group.name);
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => CapturePicturePage(
          baseUrl: widget.baseUrl,
          groupId: group.id,
          groupName: group.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? l10n = _l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.homeTakePicture ?? 'Take Picture')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadGroups,
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n?.homeRetry ?? 'Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _groups.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n?.selectCaptureNoManagerGroups ??
                              'You are not a manager for any groups yet.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _groups.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        final _CaptureGroupEntry group = _groups[index];
                        return ListTile(
                          leading: const Icon(Icons.camera_alt_outlined),
                          title: Text(group.name),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _selectGroup(group),
                        );
                      },
                    ),
    );
  }
}

class _CaptureGroupEntry {
  const _CaptureGroupEntry({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class _CaptureGroupSource {
  const _CaptureGroupSource({
    required this.id,
    required this.encryptedName,
    required this.nameNonce,
    required this.status,
  });

  factory _CaptureGroupSource.fromJson(Map<String, dynamic> json) {
    return _CaptureGroupSource(
      id: (json['uuid'] as String?)?.trim() ?? '',
      encryptedName: (json['encrypted_name'] as String?)?.trim() ?? '',
      nameNonce: (json['name_nonce'] as String?)?.trim() ?? '',
      status: (json['status'] as String?)?.trim(),
    );
  }

  final String id;
  final String encryptedName;
  final String nameNonce;
  final String? status;
}