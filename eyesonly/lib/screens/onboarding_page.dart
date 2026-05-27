import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:eyesonly/l10n/app_localizations.dart';

import 'package:eyesonly/screens/groups_page.dart';
import 'package:eyesonly/screens/main_manager/groups/create_group.dart';
import 'package:eyesonly/screens/main_manager/login_page.dart';
import 'package:eyesonly/screens/scan_qr_code_page.dart';
import 'package:eyesonly/services/api_exception.dart';
import 'package:eyesonly/services/api_service_support.dart';
import 'package:eyesonly/services/device/api_endpoints.dart';
import 'package:eyesonly/services/device/api_service.dart';
import 'package:eyesonly/services/manager/auth_token_store.dart';
import 'package:eyesonly/services/manager/device_registration_service.dart';
import 'package:eyesonly/services/push_notifications_service.dart';
import 'package:eyesonly/services/settings_store.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.initialSettings,
    required this.onCompleted,
    this.settingsStore,
    this.pushNotificationsService,
  });

  final AppSettings initialSettings;
  final VoidCallback onCompleted;
  final SettingsStore? settingsStore;
  final PushNotificationsService? pushNotificationsService;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const Duration _statusRequestTimeout = Duration(seconds: 10);
  static const Duration _membershipPollInterval = Duration(seconds: 4);

  final GlobalKey<FormState> _organizationFormKey = GlobalKey<FormState>();
  final TextEditingController _organizationUrlController =
      TextEditingController();
  final PageController _pageController = PageController();

  late final SettingsStore _settingsStore;
  late final PushNotificationsService _pushNotificationsService;

  AppSettings _settings = AppSettings.defaults;
  int _currentStep = 0;

  bool _isCheckingOrganization = false;
  String? _organizationError;
  String? _checkedOrganizationApiUrl;
  String? _checkedOrganizationName;

  bool _isPreparingJoinQr = false;
  String? _joinQrPayload;
  String? _joinQrError;
  String? _installationId;

  Timer? _membershipPollTimer;
  bool _groupMembershipConfirmed = false;
  String? _membershipPollingError;

  bool _isSubmittingPushChoice = false;
  String? _pushChoiceError;

  AppLocalizations? get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _settingsStore = widget.settingsStore ?? SettingsStore();
    _pushNotificationsService =
        widget.pushNotificationsService ?? PushNotificationsService();
    _settings = widget.initialSettings;

    // Persist onboarding as in-progress so app restarts cannot skip back to home
    // after step 1 is partially completed.
    unawaited(_settingsStore.saveOnboardingCompleted(false));

    final AppOrganization? existingOrganization = _primaryOrganization;
    if (existingOrganization != null) {
      _organizationUrlController.text = existingOrganization.apiUrl;
      _checkedOrganizationApiUrl = existingOrganization.apiUrl;
      _checkedOrganizationName = existingOrganization.name;
      _prepareJoinStep();
    }
  }

  @override
  void dispose() {
    _membershipPollTimer?.cancel();
    _organizationUrlController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  AppOrganization? get _primaryOrganization {
    if (_settings.organizations.isEmpty) {
      return null;
    }
    return _settings.organizations.first;
  }

  Future<void> _goToStep(int step) async {
    if (!_pageController.hasClients) {
      return;
    }
    await _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _checkOrganization() async {
    if (!_organizationFormKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final String apiUrl = _organizationUrlController.text.trim();

    setState(() {
      _isCheckingOrganization = true;
      _organizationError = null;
      _checkedOrganizationApiUrl = null;
      _checkedOrganizationName = null;
    });

    try {
      final ({String? orgName, String? error}) result =
          await _fetchOrganizationStatus(apiUrl);
      if (result.error != null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _organizationError = result.error;
          _isCheckingOrganization = false;
        });
        return;
      }

      if (!mounted) {
        return;
      }

      final String organizationName =
          (result.orgName?.trim().isNotEmpty ?? false)
          ? result.orgName!.trim()
          : apiUrl;

      setState(() {
        _isCheckingOrganization = false;
        _organizationError = null;
        _checkedOrganizationApiUrl = apiUrl;
        _checkedOrganizationName = organizationName;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _organizationError =
            _l10n?.onboardingOrganizationUnreachable ??
            'Could not reach the server. Please check the URL and your network connection.';
        _isCheckingOrganization = false;
        _checkedOrganizationApiUrl = null;
        _checkedOrganizationName = null;
      });
    }
  }

  Future<void> _confirmOrganizationAndContinue() async {
    final String checkedApiUrl = _checkedOrganizationApiUrl?.trim() ?? '';
    if (checkedApiUrl.isEmpty) {
      return;
    }

    final String organizationName =
        (_checkedOrganizationName?.trim().isNotEmpty ?? false)
        ? _checkedOrganizationName!.trim()
        : checkedApiUrl;

    final AppSettings currentSettings = await _settingsStore.load();
    final List<AppOrganization> updatedOrganizations =
        List<AppOrganization>.from(currentSettings.organizations);
    final int existingIndex = updatedOrganizations.indexWhere(
      (AppOrganization organization) =>
          organization.apiUrl.trim().toLowerCase() ==
          checkedApiUrl.toLowerCase(),
    );

    if (existingIndex >= 0) {
      updatedOrganizations[existingIndex] = AppOrganization(
        id: updatedOrganizations[existingIndex].id,
        name: organizationName,
        apiUrl: checkedApiUrl,
      );
    } else {
      updatedOrganizations.add(
        AppOrganization(
          id: const Uuid().v4(),
          name: organizationName,
          apiUrl: checkedApiUrl,
        ),
      );
    }

    await _settingsStore.saveOrganizations(updatedOrganizations);
    final String currentManagerUrl =
        currentSettings.managerServerURL?.trim() ?? '';
    if (currentManagerUrl.isEmpty) {
      await _settingsStore.saveManagerServerURL(checkedApiUrl);
    }

    final AppSettings refreshedSettings = await _settingsStore.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _settings = refreshedSettings;
    });

    await _prepareJoinStep();
    await _goToStep(1);
  }

  void _clearOrganizationCheckResult() {
    if (_checkedOrganizationApiUrl == null &&
        _checkedOrganizationName == null) {
      return;
    }
    setState(() {
      _checkedOrganizationApiUrl = null;
      _checkedOrganizationName = null;
    });
  }

  Future<void> _scanOrganizationQrCode() async {
    final String? scannedValue = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext context) => ScanQrCodePage(
          title: _l10n?.onboardingScanOrganizationQrTitle ??
              'Scan Organization QR Code',
          instruction: _l10n?.onboardingScanOrganizationQrInstruction ??
              'Scan the main manager organization QR code to fill the API URL.',
        ),
      ),
    );

    if (!mounted || scannedValue == null) {
      return;
    }

    final String? resolvedApiUrl = _extractApiUrlFromQr(scannedValue);
    if (resolvedApiUrl == null) {
      setState(() {
        _organizationError =
        _l10n?.onboardingOrganizationInvalidQr ??
        'The scanned QR code did not contain a valid organization API URL.';
      });
      return;
    }

    setState(() {
      _organizationUrlController.text = resolvedApiUrl;
      _organizationError = null;
      _checkedOrganizationApiUrl = null;
      _checkedOrganizationName = null;
    });
  }

  String? _extractApiUrlFromQr(String rawValue) {
    final String normalized = rawValue.trim();
    final Uri? directUri = Uri.tryParse(normalized);
    if (directUri != null &&
        directUri.hasScheme &&
        directUri.hasAuthority &&
        (directUri.scheme == 'http' || directUri.scheme == 'https')) {
      return normalized;
    }

    try {
      final dynamic decoded = jsonDecode(normalized);
      if (decoded is Map<String, dynamic>) {
        final List<String?> candidateValues = <String?>[
          decoded['api_url'] as String?,
          decoded['apiUrl'] as String?,
          decoded['url'] as String?,
        ];
        for (final String? candidate in candidateValues) {
          final String value = candidate?.trim() ?? '';
          if (value.isEmpty) {
            continue;
          }
          final Uri? parsed = Uri.tryParse(value);
          if (parsed != null &&
              parsed.hasScheme &&
              parsed.hasAuthority &&
              (parsed.scheme == 'http' || parsed.scheme == 'https')) {
            return value;
          }
        }
      }
    } catch (_) {
      // Ignore parsing errors and report invalid QR payload to the user.
    }

    return null;
  }

  Future<({String? orgName, String? error})> _fetchOrganizationStatus(
    String apiUrl,
  ) async {
    try {
      final Uri statusUri = ApiServiceSupport.buildUri(
        baseUrl: apiUrl,
        path: DeviceApiEndpoints.apiStatus,
      );
      final http.Response response = await http
          .get(statusUri)
          .timeout(_statusRequestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return (
          orgName: null,
          error: _l10n?.onboardingUnexpectedStatus(response.statusCode) ??
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
        // Response can be non-JSON. Organization name is optional.
      }

      return (orgName: orgName, error: null);
    } on TimeoutException {
      return (
        orgName: null,
        error: _l10n?.onboardingTimeout ??
            'Could not reach the server within 10 seconds.',
      );
    } catch (_) {
      return (
        orgName: null,
        error: _l10n?.onboardingOrganizationUnreachable ??
            'Could not reach the server. Please check the URL and your network connection.',
      );
    }
  }

  Future<void> _prepareJoinStep() async {
    final AppOrganization? organization = _primaryOrganization;
    if (organization == null) {
      return;
    }

    setState(() {
      _isPreparingJoinQr = true;
      _joinQrError = null;
      _joinQrPayload = null;
      _installationId = null;
      _groupMembershipConfirmed = false;
      _membershipPollingError = null;
    });

    try {
      final DeviceJoinRequestData joinRequestData =
          await DeviceRegistrationService().getOrCreateJoinRequestData();
      final String? accessToken = await AuthTokenStore().readAccessToken();
      final int? ownerUserId = DeviceRegistrationService.extractUserIdFromJwt(
        accessToken,
      );

      final String qrPayload = jsonEncode(<String, dynamic>{
        'type': 'eyesonly-device-join',
        'version': 1,
        'api_url': organization.apiUrl,
        'owner_user_id': ownerUserId,
        'manager_scope_requests': <String, dynamic>{
          'register_device': <String, dynamic>{
            'device_identifier': joinRequestData.deviceIdentifier,
            'public_key': joinRequestData.publicKey,
            'public_key_algorithm': joinRequestData.publicKeyAlgorithm,
          },
          'add_device_to_group': <String, dynamic>{
            'device_identifier': joinRequestData.deviceIdentifier,
            'group': null,
          },
        },
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _isPreparingJoinQr = false;
        _joinQrPayload = qrPayload;
        _installationId = joinRequestData.deviceIdentifier;
      });

      _startMembershipPolling();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPreparingJoinQr = false;
        _joinQrError = error.toString();
      });
    }
  }

  void _startMembershipPolling() {
    _membershipPollTimer?.cancel();
    _membershipPollTimer = Timer.periodic(
      _membershipPollInterval,
      (_) => _pollMembershipStatus(),
    );
    _pollMembershipStatus();
  }

  Future<void> _pollMembershipStatus() async {
    if (_groupMembershipConfirmed) {
      return;
    }

    final AppOrganization? organization = _primaryOrganization;
    if (organization == null) {
      return;
    }

    try {
      final DeviceSelfStatus selfStatus = await DeviceApiService(
        baseUrl: organization.apiUrl,
      ).getSelfStatus();

      if (!mounted) {
        return;
      }

      if (selfStatus.groupNames.isNotEmpty) {
        _membershipPollTimer?.cancel();
        setState(() {
          _groupMembershipConfirmed = true;
          _membershipPollingError = null;
        });

        if (_currentStep == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          if (mounted) {
            await _goToStep(2);
          }
        }
        return;
      }

      setState(() {
        _membershipPollingError = null;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (_isNoGroupsMembershipError(error)) {
        setState(() {
          _membershipPollingError = null;
        });
        return;
      }
      setState(() {
        _membershipPollingError = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _membershipPollingError = error.toString();
      });
    }
  }

  bool _isNoGroupsMembershipError(ApiException error) {
    final String normalizedErrorMessage = error.message.trim().toLowerCase();
    return error.statusCode == 401 ||
        normalizedErrorMessage.contains('you are not in any groups yet') ||
        normalizedErrorMessage.contains('device private key not found') ||
        normalizedErrorMessage.contains('device public key not found') ||
        normalizedErrorMessage.contains(
          'could not be authenticated with this server',
        );
  }

  Future<void> _openAdminFlow() async {
    final AppOrganization? organization = _primaryOrganization;
    if (organization == null) {
      return;
    }

    final bool? completedGroupSetup = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) =>
            _OnboardingAdminPage(organizationApiUrl: organization.apiUrl),
      ),
    );

    final AppSettings refreshedSettings = await _settingsStore.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _settings = refreshedSettings;
    });

    if (completedGroupSetup == true) {
      await _settingsStore.saveManagerModeEnabled(true);
      await _pollMembershipStatus();
      if (mounted && _groupMembershipConfirmed) {
        await _goToStep(2);
      }
      return;
    }

    await _pollMembershipStatus();
  }

  Future<void> _onIndicatorTapped(int index) async {
    if (index == _currentStep) {
      return;
    }

    if (index == 0) {
      await _goToStep(0);
      return;
    }

    if (index == 1) {
      if (_primaryOrganization == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _l10n?.onboardingCompleteOrganizationFirst ??
                    'Complete organization setup first.',
              ),
            ),
          );
        }
        return;
      }
      await _goToStep(1);
      return;
    }

    if (!_groupMembershipConfirmed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _l10n?.onboardingWaitingForAdminAssignment ??
                  'Waiting for admin assignment before next step.',
            ),
          ),
        );
      }
      await _pollMembershipStatus();
      return;
    }

    await _goToStep(2);
  }

  Future<void> _savePushChoiceAndFinish({required bool enablePush}) async {
    if (_isSubmittingPushChoice) {
      return;
    }

    setState(() {
      _isSubmittingPushChoice = true;
      _pushChoiceError = null;
    });

    try {
      final AppSettings refreshedSettings = await _settingsStore.load();

      if (enablePush) {
        await _pushNotificationsService.enableForOrganizations(
          baseUrls: refreshedSettings.organizations.map(
            (AppOrganization organization) => organization.apiUrl,
          ),
          fallbackBaseUrl: refreshedSettings.managerServerURL,
        );
      }

      await _settingsStore.savePushNotificationsEnabled(enablePush);
      await _settingsStore.saveOnboardingCompleted(true);

      if (!mounted) {
        return;
      }

      widget.onCompleted();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pushChoiceError = error.message;
        _isSubmittingPushChoice = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pushChoiceError = error.toString();
        _isSubmittingPushChoice = false;
      });
    }
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(
        3,
        (int index) => Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              _onIndicatorTapped(index);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: _currentStep == index ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentStep == index
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? l10n = _l10n;

    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _currentStep > 0) {
          _goToStep(_currentStep - 1);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(l10n?.onboardingWelcomeTitle ?? 'Welcome to Eyes Only'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (int pageIndex) {
                    setState(() {
                      _currentStep = pageIndex;
                    });
                  },
                  children: [
                    _buildOrganizationStep(context),
                    _buildJoinGroupStep(context),
                    _buildPushNotificationsStep(context),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildPageIndicators(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrganizationStep(BuildContext context) {
    final AppLocalizations? l10n = _l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _organizationFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n?.onboardingStep1Title ?? 'Step 1: Connect your organization',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              l10n?.onboardingStep1Body ??
                  'Enter your organization API URL. We will verify it before continuing.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _organizationUrlController,
              decoration: InputDecoration(
                labelText: l10n?.onboardingOrganizationApiUrlLabel ??
                    'Organization API URL',
                hintText: l10n?.onboardingOrganizationApiUrlHint ??
                    'https://api.example.com',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              validator: (String? value) {
                final String normalizedValue = value?.trim() ?? '';
                if (normalizedValue.isEmpty) {
                  return l10n?.onboardingApiUrlRequired ?? 'API URL is required';
                }
                final Uri? parsed = Uri.tryParse(normalizedValue);
                if (parsed == null ||
                    !parsed.hasScheme ||
                    (parsed.scheme != 'http' && parsed.scheme != 'https') ||
                    !parsed.hasAuthority) {
                  return l10n?.onboardingApiUrlInvalid ??
                      'Enter a valid http or https URL';
                }
                return null;
              },
              onChanged: (String value) {
                final String checkedApiUrl =
                    _checkedOrganizationApiUrl?.trim() ?? '';
                if (checkedApiUrl.isNotEmpty && value.trim() != checkedApiUrl) {
                  _clearOrganizationCheckResult();
                }
              },
              onFieldSubmitted: (_) =>
                  _isCheckingOrganization ? null : _checkOrganization(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isCheckingOrganization
                  ? null
                  : _scanOrganizationQrCode,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(
                l10n?.onboardingScanOrganizationQrAction ??
                    'Scan organization QR code',
              ),
            ),
            if (_organizationError != null) ...[
              const SizedBox(height: 12),
              Text(
                _organizationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isCheckingOrganization ? null : _checkOrganization,
              child: Text(
                _isCheckingOrganization
                    ? (l10n?.onboardingCheckingOrganization ??
                        'Checking organization...')
                    : (l10n?.onboardingCheckOrganizationAction ??
                        'Check organization'),
              ),
            ),
            if (_isCheckingOrganization) ...[
              const SizedBox(height: 16),
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ],
            if (_checkedOrganizationApiUrl != null) ...[
              const SizedBox(height: 20),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _checkedOrganizationName ?? _checkedOrganizationApiUrl!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_checkedOrganizationName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _checkedOrganizationApiUrl!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        l10n?.onboardingContinueWithOrganizationPrompt ??
                            'Continue with this organization?',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: _confirmOrganizationAndContinue,
                            child: Text(
                              l10n?.onboardingContinueAction ?? 'Continue',
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: _clearOrganizationCheckResult,
                            child: Text(l10n?.onboardingCancelAction ?? 'Cancel'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJoinGroupStep(BuildContext context) {
    final AppLocalizations? l10n = _l10n;
    final AppOrganization? organization = _primaryOrganization;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n?.onboardingStep2Title ?? 'Step 2: Join your first group',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            l10n?.onboardingStep2Body ??
                'Show this QR code to your organization admin. We will keep checking until this device is assigned to a group.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (organization != null)
            Text(
              organization.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          const SizedBox(height: 16),
          if (_isPreparingJoinQr)
            const Center(child: CircularProgressIndicator())
          else if (_joinQrError != null)
            Text(
              _joinQrError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else if (_joinQrPayload != null)
            Center(
              child: QrImageView(
                data: _joinQrPayload!,
                version: QrVersions.auto,
                size: 280,
                backgroundColor: Colors.white,
              ),
            ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_groupMembershipConfirmed)
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      else
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _groupMembershipConfirmed
                              ? (l10n?.onboardingMembershipConfirmed ??
                                  'Group membership confirmed.')
                              : (l10n?.onboardingWaitingForAdminAssignmentShort ??
                                  'Waiting for admin assignment...'),
                        ),
                      ),
                    ],
                  ),
                  if (_membershipPollingError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _membershipPollingError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: ExpansionTile(
                title: Text(l10n?.onboardingWhatIsSharedTitle ?? 'What is shared?'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(
                    l10n?.onboardingWhatIsSharedBody ??
                        'This QR code shares the organization server URL, this installation identifier, and this device public key data so a main manager can register the device and add it to a selected group.',
                    textAlign: TextAlign.left,
                  ),
                  if (_installationId != null) ...[
                    const SizedBox(height: 12),
                    SelectableText(
                      l10n?.onboardingInstallationIdentifier(_installationId!) ??
                          'Installation Identifier: $_installationId',
                      textAlign: TextAlign.left,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
                onPressed: _openAdminFlow,
                child: Text(
                  l10n?.onboardingIAmMainManagerAction ?? 'I am a manager',
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _groupMembershipConfirmed ? () => _goToStep(2) : null,
            child: Text(l10n?.onboardingContinueAction ?? 'Continue'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _goToStep(0),
            child: Text(l10n?.onboardingBackAction ?? 'Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildPushNotificationsStep(BuildContext context) {
    final AppLocalizations? l10n = _l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n?.onboardingStep3Title ?? 'Step 3: Push notifications',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            l10n?.onboardingStep3Body ??
                'Do you want to receive push notifications for new group images?',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Text(
            l10n?.onboardingPushPrivacyBody ??
                'If enabled, this device communicates with Google Firebase servers only to receive notification events. Image content is not sent to Firebase.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.onboardingPushPermissionBody ??
                'On Android 12 and lower, the system usually does not show a notification permission popup. On Android 13+ and iOS, the OS may ask for permission.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_pushChoiceError != null) ...[
            const SizedBox(height: 12),
            Text(
              _pushChoiceError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSubmittingPushChoice
                ? null
                : () => _savePushChoiceAndFinish(enablePush: true),
            child: Text(
              _isSubmittingPushChoice
                  ? (l10n?.onboardingApplying ?? 'Applying...')
                  : (l10n?.onboardingEnableNotificationsAction ??
                      'Enable notifications'),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _isSubmittingPushChoice
                ? null
                : () => _savePushChoiceAndFinish(enablePush: false),
            child: Text(l10n?.onboardingNotNowAction ?? 'Not now'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isSubmittingPushChoice ? null : () => _goToStep(1),
            child: Text(l10n?.onboardingBackAction ?? 'Back'),
          ),
        ],
      ),
    );
  }
}

class _OnboardingAdminPage extends StatefulWidget {
  const _OnboardingAdminPage({required this.organizationApiUrl});

  final String organizationApiUrl;

  @override
  State<_OnboardingAdminPage> createState() => _OnboardingAdminPageState();
}

class _OnboardingAdminPageState extends State<_OnboardingAdminPage> {
  final SettingsStore _settingsStore = SettingsStore();

  bool _isRefreshing = true;
  bool _isLoggedIn = false;
  String? _username;

  AppLocalizations? get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _refreshState();
  }

  Future<void> _refreshState() async {
    setState(() {
      _isRefreshing = true;
    });

    final AppSettings settings = await _settingsStore.load();
    final String managerUrl = settings.managerServerURL?.trim() ?? '';
    if (managerUrl.isEmpty) {
      await _settingsStore.saveManagerServerURL(widget.organizationApiUrl);
    }

    final AppSettings refreshed = await _settingsStore.load();
    if (!mounted) {
      return;
    }

    final String username = refreshed.lastLoggedInUsername?.trim() ?? '';
    setState(() {
      _username = username.isEmpty ? null : username;
      _isLoggedIn = username.isNotEmpty;
      _isRefreshing = false;
    });
  }

  Future<void> _openLogin() async {
    final bool? loginSuccess = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => const LoginPage(),
      ),
    );

    if (loginSuccess == true) {
      await _settingsStore.saveManagerModeEnabled(true);
      await _refreshState();
    }
  }

  Future<void> _openCreateGroup() async {
    final NavigatorState navigator = Navigator.of(context);
    final AppSettings settings = await _settingsStore.load();
    final String baseUrl = settings.managerServerURL?.trim().isNotEmpty == true
        ? settings.managerServerURL!.trim()
        : widget.organizationApiUrl;

    await _settingsStore.saveManagerServerURL(baseUrl);

    if (!mounted) {
      return;
    }

    final bool? created = await navigator.push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => CreateGroupPage(baseUrl: baseUrl),
      ),
    );

    if (!mounted || created != true) {
      return;
    }

    navigator.pop(true);
  }

  Future<void> _openJoinGroup() async {
    final NavigatorState navigator = Navigator.of(context);
    final bool hadMembershipBefore = await _hasAnyGroupMembership();

    await navigator.push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => const GroupsPage(),
      ),
    );

    if (!mounted) {
      return;
    }

    final bool hasMembershipAfter = await _hasAnyGroupMembership();
    if (!hadMembershipBefore && hasMembershipAfter && mounted) {
      navigator.pop(true);
    }
  }

  Future<bool> _hasAnyGroupMembership() async {
    final AppSettings settings = await _settingsStore.load();
    for (final AppOrganization organization in settings.organizations) {
      try {
        final DeviceSelfStatus selfStatus = await DeviceApiService(
          baseUrl: organization.apiUrl,
        ).getSelfStatus();
        if (selfStatus.groupNames.isNotEmpty) {
          return true;
        }
      } on ApiException catch (error) {
        if (_isNoGroupsMembershipError(error)) {
          continue;
        }
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  bool _isNoGroupsMembershipError(ApiException error) {
    final String normalizedErrorMessage = error.message.trim().toLowerCase();
    return error.statusCode == 401 ||
        normalizedErrorMessage.contains('you are not in any groups yet') ||
        normalizedErrorMessage.contains('device private key not found') ||
        normalizedErrorMessage.contains('device public key not found') ||
        normalizedErrorMessage.contains(
          'could not be authenticated with this server',
        );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? l10n = _l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.onboardingAdminTitle ?? 'Admin Onboarding'),
      ),
      body: SafeArea(
        child: _isRefreshing
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n?.onboardingAdminSetupTitle ?? 'Main manager setup',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isLoggedIn
                          ? (l10n?.onboardingAdminLoggedInAs(_username ?? '') ??
                              'Logged in as $_username. You can now create a group or join a group.')
                          : (l10n?.onboardingAdminLoginPrompt ??
                              'Log in with a main manager account to continue with admin actions.'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    if (!_isLoggedIn)
                      FilledButton.icon(
                        onPressed: _openLogin,
                        icon: const Icon(Icons.login),
                        label: Text(
                          l10n?.onboardingAdminLoginAction ??
                              'Log in as main manager',
                        ),
                      )
                    else ...[
                      FilledButton.icon(
                        onPressed: _openCreateGroup,
                        icon: const Icon(Icons.add),
                        label: Text(
                          l10n?.createGroupTitle ?? 'Create group',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _openJoinGroup,
                        icon: const Icon(Icons.group_add),
                        label: Text(
                          l10n?.groupsJoinGroup ?? 'Join group',
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
