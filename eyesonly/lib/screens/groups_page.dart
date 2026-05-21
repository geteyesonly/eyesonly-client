
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:eyesonly/screens/add_organization_page.dart';
import 'package:eyesonly/screens/group_detail_page.dart';
import 'package:eyesonly/screens/join_group_qr_page.dart';
import 'package:eyesonly/screens/share_organization_qr_page.dart';
import 'package:eyesonly/screens/main_manager/groups/create_group.dart';
import 'package:eyesonly/l10n/app_localizations.dart';
import 'package:eyesonly/services/api_service_support.dart';
import 'package:eyesonly/services/api_exception.dart';
import 'package:eyesonly/services/device/api_endpoints.dart';
import 'package:eyesonly/services/group_display_service.dart';
import 'package:eyesonly/services/screen_feedback.dart';
import 'package:eyesonly/services/settings_store.dart';
import 'package:eyesonly/services/device/api_service.dart';

typedef OrganizationNameFetcher = Future<String?> Function(String apiUrl);
typedef DeviceGroupsFetcher = Future<List<DeviceGroup>> Function(String baseUrl);

class GroupsPage extends StatefulWidget {
  const GroupsPage({
    super.key,
    this.settingsStore,
    this.groupDisplayService,
    this.organizationNameFetcher,
    this.groupsFetcher,
  });

  final SettingsStore? settingsStore;
  final GroupDisplayService? groupDisplayService;
  final OrganizationNameFetcher? organizationNameFetcher;
  final DeviceGroupsFetcher? groupsFetcher;

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  static const Duration _serverTimeout = Duration(seconds: 10);

  late final SettingsStore _settingsStore;
  late final GroupDisplayService _groupDisplayService;
  bool _isLoading = true;
  bool _managerModeEnabled = false;
  String? _lastLoggedInUsername;
  List<_OrgGroups> _orgGroupsList = [];
  String? _error;

  bool get _canCreateGroups =>
      _managerModeEnabled &&
      (_lastLoggedInUsername?.trim().isNotEmpty ?? false);

  AppLocalizations? get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _settingsStore = widget.settingsStore ?? SettingsStore();
    _groupDisplayService = widget.groupDisplayService ?? GroupDisplayService();
    _loadGroups();
  }

  Future<void> _openAddOrganizationPage() async {
    final bool? added = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => const AddOrganizationPage(),
      ),
    );

    if (!mounted) {
      return;
    }

    if (added == true) {
      await _loadGroups();
      // Auto-select as manager server if manager mode is on, no URL set yet,
      // and this was the first org added.
      if (_managerModeEnabled) {
        final AppSettings settings = await _settingsStore.load();
        if (settings.managerServerURL == null && settings.organizations.length == 1) {
          await _settingsStore.saveManagerServerURL(
            settings.organizations.first.apiUrl,
          );
        }
      }
    }
  }

  Future<void> _openGroupDetailPage(_GroupListEntry group, _OrgGroups orgGroups) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => GroupDetailPage(
          groupId: group.id,
          groupName: group.name,
          baseUrl: group.baseUrl,
          organizationName: orgGroups.organizationName,
          isManager: _canCreateGroups,
        ),
      ),
    );
    if (changed == true) {
      await _loadGroups();
    }
  }

  Future<void> _openJoinGroupPage(_OrgGroups organization) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => JoinGroupQrPage(
          organizationName: organization.organizationName,
          apiUrl: organization.organizationApiUrl,
        ),
      ),
    );
  }

  Future<void> _openShareOrganizationPage(_OrgGroups organization) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ShareOrganizationQrPage(
          organizationName: organization.organizationName,
          apiUrl: organization.organizationApiUrl,
        ),
      ),
    );
  }

  Future<void> _openCreateGroupPage() async {
    try {
      final AppSettings settings = await _settingsStore.load();
      final String baseUrl = settings.managerServerURL?.trim() ?? '';
      if (baseUrl.isEmpty) {
        if (!mounted) {
          return;
        }
        ScreenFeedback.showMessage(
          context,
          _l10n?.managerServerNotSet ?? 'Manager server URL is not set.',
        );
        return;
      }

      if (!mounted) {
        return;
      }

      final bool? created = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (BuildContext context) => CreateGroupPage(baseUrl: baseUrl),
        ),
      );

      if (created == true) {
        await _loadGroups();
      }
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

  Future<List<_GroupListEntry>> _resolveGroupEntries(
    AppOrganization organization,
    List<DeviceGroup> groups,
  ) async {
    await _groupDisplayService.syncGroupKeysFromDeviceEndpoint(
      baseUrl: organization.apiUrl,
      groupIds: groups.map((DeviceGroup group) => group.uuid),
    ).timeout(_serverTimeout);

    final List<_GroupListEntry> entries = <_GroupListEntry>[];
    for (final DeviceGroup group in groups) {
      final String resolvedName = await _groupDisplayService.tryDecryptGroupName(
            groupId: group.uuid,
            encryptedName: group.encryptedName,
            nameNonce: group.nameNonce,
          ) ??
          (_l10n?.groupsFallbackName(group.uuid.substring(0, 8)) ??
              'Group ${group.uuid.substring(0, 8)}');
      entries.add(
        _GroupListEntry(
          id: group.uuid,
          name: resolvedName,
          baseUrl: organization.apiUrl,
        ),
      );
    }

    entries.sort(
      (_GroupListEntry a, _GroupListEntry b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return entries;
  }

  String _serverTimeoutMessage(AppOrganization organization) {
    return _l10n?.groupsServerTimeoutWithUrl(organization.apiUrl) ??
        'Could not reach ${organization.apiUrl} within 10 seconds.';
  }

  Future<String?> _fetchOrganizationNameFromStatusEndpoint(String apiUrl) async {
    final OrganizationNameFetcher? organizationNameFetcher =
        widget.organizationNameFetcher;
    if (organizationNameFetcher != null) {
      return organizationNameFetcher(apiUrl);
    }

    try {
      final Uri statusUri = ApiServiceSupport.buildUri(
        baseUrl: apiUrl,
        path: DeviceApiEndpoints.apiStatus,
      );
      final http.Response response = await http
          .get(statusUri)
          .timeout(_serverTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final String organizationName =
          (decoded['organization'] as String?)?.trim() ?? '';
      return organizationName.isEmpty ? null : organizationName;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadGroups() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _orgGroupsList = [];
    });
    try {
      final AppSettings settings = await _settingsStore.load();
      final List<AppOrganization> organizations =
          List<AppOrganization>.from(settings.organizations);
      final List<AppOrganization> updatedOrganizations = <AppOrganization>[];
      final List<_OrgGroups> orgGroupsList = <_OrgGroups>[];
      bool organizationsChanged = false;

      for (final AppOrganization organization in organizations) {
        final String? statusOrganizationName =
            await _fetchOrganizationNameFromStatusEndpoint(organization.apiUrl);
        final AppOrganization statusResolvedOrganization =
            statusOrganizationName != null &&
                statusOrganizationName != organization.name
            ? AppOrganization(
                id: organization.id,
                name: statusOrganizationName,
                apiUrl: organization.apiUrl,
              )
            : organization;
        if (statusResolvedOrganization.name != organization.name) {
          organizationsChanged = true;
        }

        try {
          final List<DeviceGroup> groups = await (widget.groupsFetcher != null
                  ? widget.groupsFetcher!(statusResolvedOrganization.apiUrl)
                  : DeviceApiService(
                      baseUrl: statusResolvedOrganization.apiUrl,
                    ).getGroups())
              .timeout(_serverTimeout);
          updatedOrganizations.add(statusResolvedOrganization);

          final List<_GroupListEntry> groupEntries = await _resolveGroupEntries(
            statusResolvedOrganization,
            groups,
          );

          orgGroupsList.add(
            _OrgGroups(
              organizationId: statusResolvedOrganization.id,
              organizationName: statusResolvedOrganization.name,
              organizationApiUrl: statusResolvedOrganization.apiUrl,
              groups: groupEntries,
            ),
          );
        } on TimeoutException {
          updatedOrganizations.add(statusResolvedOrganization);
          orgGroupsList.add(
            _OrgGroups(
              organizationId: statusResolvedOrganization.id,
              organizationName: statusResolvedOrganization.name,
              organizationApiUrl: statusResolvedOrganization.apiUrl,
              groups: const <_GroupListEntry>[],
              errorMessage: _serverTimeoutMessage(statusResolvedOrganization),
            ),
          );
        } on ApiException catch (error) {
          updatedOrganizations.add(statusResolvedOrganization);
          // Treat unregistered-device authentication failures as empty groups.
          final String normalizedErrorMessage = error.message
              .trim()
              .toLowerCase();
          final bool isUnauthorized =
              error.statusCode == 401 ||
              normalizedErrorMessage.contains('device private key not found') ||
              normalizedErrorMessage.contains('device public key not found') ||
              normalizedErrorMessage.contains('you are not in any groups yet') ||
              normalizedErrorMessage.contains(
                'could not be authenticated with this server',
              );
          orgGroupsList.add(
            _OrgGroups(
              organizationId: statusResolvedOrganization.id,
              organizationName: statusResolvedOrganization.name,
              organizationApiUrl: statusResolvedOrganization.apiUrl,
              groups: const <_GroupListEntry>[],
              errorMessage: isUnauthorized ? null : error.message,
            ),
          );
        } catch (e) {
          updatedOrganizations.add(statusResolvedOrganization);
          orgGroupsList.add(
            _OrgGroups(
              organizationId: statusResolvedOrganization.id,
              organizationName: statusResolvedOrganization.name,
              organizationApiUrl: statusResolvedOrganization.apiUrl,
              groups: const <_GroupListEntry>[],
              errorMessage: e.toString(),
            ),
          );
        }
      }

      if (organizationsChanged) {
        await _settingsStore.saveOrganizations(updatedOrganizations);
      }

      orgGroupsList.sort(
          (_OrgGroups a, _OrgGroups b) =>
              a.organizationName.toLowerCase().compareTo(
                    b.organizationName.toLowerCase(),
                  ),
        );

      if (!mounted) {
        return;
      }

      setState(() {
        _managerModeEnabled = settings.managerModeEnabled;
        _lastLoggedInUsername = settings.lastLoggedInUsername;
        _orgGroupsList = orgGroupsList;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = e is TimeoutException
            ? (_l10n?.groupsServerTimeout ??
                'Could not reach the server within 10 seconds.')
            : e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? l10n = _l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.groupsTitle ?? 'Groups'),
        actions: [
          if (_canCreateGroups)
            IconButton(
              onPressed: _isLoading ? null : _loadGroups,
              icon: const Icon(Icons.refresh),
              tooltip: l10n?.groupsRefresh ?? 'Refresh',
            ),
        ],
      ),
      floatingActionButton: _canCreateGroups
          ? FloatingActionButton.extended(
              onPressed: _openCreateGroupPage,
              icon: const Icon(Icons.add),
              label: Text(l10n?.groupsCreateGroup ?? 'Create Group'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    l10n?.groupsError(_error!) ?? 'Error: $_error',
                  ),
                )
              : ListView(
                  children: [
                    if (_orgGroupsList.isEmpty)
                      ListTile(
                        title: Text(
                          l10n?.settingsNoOrganizations ??
                              'No organizations yet',
                        ),
                        subtitle: Text(
                          l10n?.groupsAddOrganizationToSeeGroups ??
                              'Add an organization to see its groups here.',
                        ),
                      ),
                    for (final _OrgGroups orgGroups in _orgGroupsList) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Text(
                          orgGroups.organizationName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (orgGroups.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            orgGroups.errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        )
                      else if (orgGroups.groups.isEmpty)
                        ListTile(
                          title: Text(l10n?.groupsNoGroups ?? 'No groups'),
                        )
                      else
                        ...orgGroups.groups.map(
                          (_GroupListEntry group) => ListTile(
                            leading: const Icon(Icons.group_outlined),
                            title: Text(group.name),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openGroupDetailPage(group, orgGroups),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _openJoinGroupPage(orgGroups),
                              icon: const Icon(Icons.group_add),
                              label: Text(l10n?.groupsJoinGroup ?? 'Join Group'),
                            ),
                            if (_managerModeEnabled)
                              OutlinedButton.icon(
                                onPressed: () => _openShareOrganizationPage(orgGroups),
                                icon: const Icon(Icons.qr_code_2),
                                label: Text(
                                  l10n?.groupsShareOrganization ??
                                      'Share Organization',
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _openAddOrganizationPage,
                          icon: const Icon(Icons.add_business),
                          label: Text(
                            l10n?.settingsAddOrganization ??
                                'Add Organization',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _OrgGroups {
  final String organizationId;
  final String organizationName;
  final String organizationApiUrl;
  final List<_GroupListEntry> groups;
  final String? errorMessage;

  _OrgGroups({
    required this.organizationId,
    required this.organizationName,
    required this.organizationApiUrl,
    required this.groups,
    this.errorMessage,
  });
}

class _GroupListEntry {
  const _GroupListEntry({
    required this.id,
    required this.name,
    required this.baseUrl,
  });

  final String id;
  final String name;
  final String baseUrl;
}