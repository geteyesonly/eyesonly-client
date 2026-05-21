import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:http/http.dart' as http;

import 'package:eyesonly/l10n/app_localizations.dart';
import 'package:eyesonly/screens/scan_qr_code_page.dart';
import 'package:eyesonly/services/api_service_support.dart';
import 'package:eyesonly/services/device/api_endpoints.dart';
import 'package:eyesonly/services/screen_feedback.dart';
import 'package:eyesonly/services/settings_store.dart';

typedef OrganizationStatusFetcher = Future<({String? orgName, String? error})>
    Function(String apiUrl);

class AddOrganizationPage extends StatefulWidget {
  const AddOrganizationPage({
    super.key,
    this.settingsStore,
    this.uuid,
    this.statusFetcher,
    this.scanQrCode,
  });

  final SettingsStore? settingsStore;
  final Uuid? uuid;
  final OrganizationStatusFetcher? statusFetcher;
  final Future<String?> Function(BuildContext context)? scanQrCode;

  @override
  State<AddOrganizationPage> createState() => _AddOrganizationPageState();
}

class _AddOrganizationPageState extends State<AddOrganizationPage> {
  static const Duration _serverReachabilityTimeout = Duration(seconds: 10);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _apiUrlController = TextEditingController();
  late final SettingsStore _settingsStore;
  late final Uuid _uuid;

  bool _isSaving = false;
  String? _saveError;
  // Non-null once the server check passed; triggers confirmation card.
  String? _confirmedApiUrl;
  String? _confirmedOrgName;
  List<AppOrganization> _existingOrganizations = <AppOrganization>[];

  AppLocalizations? get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _settingsStore = widget.settingsStore ?? SettingsStore();
    _uuid = widget.uuid ?? const Uuid();
    _loadExistingOrganizations();
  }

  Future<void> _loadExistingOrganizations() async {
    final AppSettings settings = await _settingsStore.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _existingOrganizations = settings.organizations;
    });
  }

  bool _apiUrlExists(String candidateUrl) {
    final String normalizedCandidate = candidateUrl.trim().toLowerCase();
    return _existingOrganizations.any(
      (AppOrganization organization) =>
          organization.apiUrl.trim().toLowerCase() == normalizedCandidate,
    );
  }

  // Step 1: validate URL, hit /status/, show confirmation card.
  Future<void> _checkServer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
      _saveError = null;
      _confirmedApiUrl = null;
      _confirmedOrgName = null;
    });

    final String normalizedApiUrl = _apiUrlController.text.trim();
    final ({String? orgName, String? error}) result =
      await _resolveServerStatus(normalizedApiUrl);

    if (!mounted) {
      return;
    }

    if (result.error != null) {
      setState(() {
        _isSaving = false;
        _saveError = result.error;
      });
      return;
    }

    setState(() {
      _isSaving = false;
      _confirmedApiUrl = normalizedApiUrl;
      _confirmedOrgName = result.orgName;
    });
  }

  Future<({String? orgName, String? error})> _resolveServerStatus(
    String apiUrl,
  ) {
    final OrganizationStatusFetcher? statusFetcher = widget.statusFetcher;
    if (statusFetcher != null) {
      return statusFetcher(apiUrl);
    }
    return _fetchServerStatus(apiUrl);
  }

  // Step 2: user confirmed — persist and pop.
  Future<void> _confirmAndSave() async {
    final String? apiUrl = _confirmedApiUrl;
    if (apiUrl == null) {
      return;
    }

    final String orgName =
        (_confirmedOrgName?.trim().isNotEmpty ?? false)
            ? _confirmedOrgName!.trim()
            : apiUrl;

    final AppOrganization organization = AppOrganization(
      id: _uuid.v4(),
      name: orgName,
      apiUrl: apiUrl,
    );

    final List<AppOrganization> updatedOrganizations = <AppOrganization>[
      ..._existingOrganizations,
      organization,
    ];
    await _settingsStore.saveOrganizations(updatedOrganizations);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  void _cancelConfirmation() {
    setState(() {
      _confirmedApiUrl = null;
      _confirmedOrgName = null;
    });
  }

  Future<({String? orgName, String? error})> _fetchServerStatus(
    String apiUrl,
  ) async {
    try {
      final Uri statusUri = ApiServiceSupport.buildUri(
        baseUrl: apiUrl,
        path: DeviceApiEndpoints.apiStatus,
      );
      final http.Response response = await http
          .get(statusUri)
          .timeout(_serverReachabilityTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return (
          orgName: null,
          error: _l10n?.addOrganizationUnexpectedStatus(response.statusCode) ??
              'Server returned an unexpected status (${response.statusCode}). Please check the URL.',
        );
      }
      String? orgName;
      try {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          orgName = (decoded['organization'] as String?)?.trim();
          if (orgName?.isEmpty ?? true) {
            orgName = null;
          }
        }
      } catch (_) {
        // Body may not be JSON — org name simply stays null.
      }
      return (orgName: orgName, error: null);
    } on TimeoutException {
      return (
        orgName: null,
        error: _l10n?.addOrganizationTimeout ??
            'Could not reach the server within 10 seconds.',
      );
    } catch (_) {
      return (
        orgName: null,
        error: _l10n?.addOrganizationUnreachable ??
            'Could not reach the server. Please check the URL and your network connection.',
      );
    }
  }

  Future<void> _openScanQrCodePage() async {
    final String? scannedValue = await (widget.scanQrCode?.call(context) ??
        Navigator.push<String>(
          context,
          MaterialPageRoute<String>(
            builder: (BuildContext context) => const ScanQrCodePage(),
          ),
        ));

    if (!mounted || scannedValue == null) {
      return;
    }

    final String normalizedValue = scannedValue.trim();
    final Uri? parsed = Uri.tryParse(normalizedValue);
    if (normalizedValue.isEmpty ||
        parsed == null ||
        !parsed.hasScheme ||
        (parsed.scheme != 'http' && parsed.scheme != 'https') ||
        !parsed.hasAuthority) {
      ScreenFeedback.showMessage(
        context,
        _l10n?.addOrganizationInvalidQr ??
            'The scanned QR code did not contain a valid API URL.',
      );
      return;
    }

    setState(() {
      _apiUrlController.text = normalizedValue;
    });
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? l10n = _l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.settingsAddOrganization ?? 'Add Organization'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _apiUrlController,
                  decoration: InputDecoration(
                    labelText: l10n?.addOrganizationApiUrlLabel ?? 'API URL',
                    hintText: l10n?.addOrganizationApiUrlHint ??
                        'https://api.example.com',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  validator: (String? value) {
                    final String normalizedValue = value?.trim() ?? '';
                    if (normalizedValue.isEmpty) {
                      return l10n?.addOrganizationApiUrlRequired ??
                          'API URL is required';
                    }
                    final Uri? parsed = Uri.tryParse(normalizedValue);
                    if (parsed == null ||
                        !parsed.hasScheme ||
                        (parsed.scheme != 'http' && parsed.scheme != 'https') ||
                        !parsed.hasAuthority) {
                      return l10n?.addOrganizationApiUrlInvalid ??
                          'Enter a valid http or https URL';
                    }
                    if (_apiUrlExists(normalizedValue)) {
                      return l10n?.addOrganizationApiUrlDuplicate ??
                          'This API URL has already been added';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _isSaving || _confirmedApiUrl != null ? null : _checkServer(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSaving || _confirmedApiUrl != null
                      ? null
                      : _checkServer,
                  child: Text(
                    _isSaving
                        ? (l10n?.addOrganizationChecking ??
                            'Checking organization...')
                        : (l10n?.addOrganizationCheckAction ??
                            'Check Organization'),
                  ),
                ),
                const SizedBox(height: 12),
                if (_isSaving)
                  const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                if (_saveError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (_confirmedApiUrl != null) ...[
                  const SizedBox(height: 20),
                  Card(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _confirmedOrgName ?? _confirmedApiUrl!,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (_confirmedOrgName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _confirmedApiUrl!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text(
                            l10n?.addOrganizationConfirmPrompt ??
                                'Add this organization?',
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              FilledButton(
                                onPressed: _confirmAndSave,
                                child: Text(l10n?.addOrganizationAdd ?? 'Add'),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                onPressed: _cancelConfirmation,
                                child: Text(l10n?.addOrganizationCancel ?? 'Cancel'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openScanQrCodePage,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(l10n?.scanQrTitle ?? 'Scan QR Code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}