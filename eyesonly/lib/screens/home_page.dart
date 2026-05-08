import 'package:eyesonly/screens/main_manager/account_page.dart';
import 'package:eyesonly/screens/add_organization_page.dart';
import 'package:eyesonly/screens/about_page.dart';
import 'package:eyesonly/screens/main_manager/groups/group_push_notification_page.dart';
import 'package:eyesonly/screens/main_manager/select_capture_group_page.dart';
import 'package:eyesonly/screens/groups_page.dart';
import 'package:eyesonly/screens/main_manager/login_page.dart';
import 'package:eyesonly/screens/settings_page.dart';
import 'package:eyesonly/services/api_exception.dart';
import 'package:eyesonly/services/device/api_service.dart';
import 'package:eyesonly/services/device_encrypted_image_feed_service.dart';
import 'package:eyesonly/services/manager/group_notification_service.dart';
import 'package:eyesonly/services/screen_feedback.dart';
import 'package:eyesonly/services/settings_store.dart';
import 'package:flutter/material.dart';

typedef DeviceMembershipChecker = Future<bool?> Function(
  List<String> deviceServerUrls,
);
typedef GroupsPageBuilder = Widget Function(BuildContext context);
typedef AddOrganizationPageBuilder = Widget Function(BuildContext context);
typedef CaptureGroupPageBuilder = Widget Function(
  BuildContext context,
  String baseUrl,
);

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    this.onSettingsChanged,
    this.settingsStore,
    this.imageFeedService,
    this.membershipChecker,
    this.groupsPageBuilder,
    this.addOrganizationPageBuilder,
    this.captureGroupPageBuilder,
  });

  final String title;
  final VoidCallback? onSettingsChanged;
  final SettingsStore? settingsStore;
  final DeviceEncryptedImageFeedService? imageFeedService;
  final DeviceMembershipChecker? membershipChecker;
  final GroupsPageBuilder? groupsPageBuilder;
  final AddOrganizationPageBuilder? addOrganizationPageBuilder;
  final CaptureGroupPageBuilder? captureGroupPageBuilder;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const String _noGroupsYetMessage = 'You are not in any groups yet.';

  late final SettingsStore _settingsStore;
  late final DeviceEncryptedImageFeedService _imageFeedService;
  bool _isCheckingGroupMembership = true;
  bool _isLoadingImages = false;
  bool? _isInGroup;
  String? _startupErrorMessage;
  bool _managerModeEnabled = false;
  String? _lastLoggedInUsername;
  List<DeviceEncryptedImageFeedSection> _imageSections =
      <DeviceEncryptedImageFeedSection>[];
  String? _imageErrorMessage;
  int _imageLoadGeneration = 0;

  bool get _canTakePictures =>
      _managerModeEnabled &&
      (_lastLoggedInUsername?.trim().isNotEmpty ?? false) &&
      !_isCheckingGroupMembership;

  @override
  void initState() {
    super.initState();
    _settingsStore = widget.settingsStore ?? SettingsStore();
    _imageFeedService =
        widget.imageFeedService ?? DeviceEncryptedImageFeedService();
    _loadSettings();
  }

  Future<bool?> _checkDeviceGroupMembership(
    List<String> deviceServerUrls,
  ) async {
    final DeviceMembershipChecker? membershipChecker = widget.membershipChecker;
    if (membershipChecker != null) {
      return membershipChecker(deviceServerUrls);
    }

    if (deviceServerUrls.isEmpty) {
      return false;
    }

    final List<bool?> membershipResults = await Future.wait(
      deviceServerUrls.map((String baseUrl) async {
        try {
          final DeviceApiService deviceApiService = DeviceApiService(
            baseUrl: baseUrl,
          );
          final DeviceSelfStatus status = await deviceApiService
              .getSelfStatus()
              .timeout(const Duration(seconds: 8));
          return status.groupNames.isNotEmpty;
        } on ApiException catch (error) {
          if (_isNoGroupsMembershipError(error)) {
            return false;
          }
          return null;
        } catch (_) {
          return null;
        }
      }),
    );

    if (membershipResults.contains(true)) {
      return true;
    }
    if (membershipResults.contains(false)) {
      return false;
    }
    return null;
  }

  Future<void> _loadSettings() async {
    final int loadGeneration = ++_imageLoadGeneration;
    if (mounted) {
      setState(() {
        _isCheckingGroupMembership = true;
        _startupErrorMessage = null;
      });
    }

    try {
      final AppSettings settings = await _settingsStore.load();
      final bool? isInGroup = await _checkDeviceGroupMembership(
        settings.deviceServerURLs,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isCheckingGroupMembership = false;
        _isInGroup = isInGroup;
        _managerModeEnabled = settings.managerModeEnabled;
        _lastLoggedInUsername = settings.lastLoggedInUsername;
        _imageSections = <DeviceEncryptedImageFeedSection>[];
        _isLoadingImages = settings.deviceServerURLs.isNotEmpty;
        _imageErrorMessage = null;
        _startupErrorMessage =
            settings.deviceServerURLs.isNotEmpty && isInGroup == null
            ? 'Could not reach your device server. Please check your network connection and server availability, then try again.'
            : null;
      });

      if (settings.deviceServerURLs.isNotEmpty) {
        await _loadEncryptedImages(settings, loadGeneration);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCheckingGroupMembership = false;
        _isLoadingImages = false;
        _isInGroup = null;
        _imageSections = <DeviceEncryptedImageFeedSection>[];
        _imageErrorMessage = null;
        _startupErrorMessage =
            'An error occurred while loading startup data. Please try again.';
      });
    }
  }

  Future<void> _loadEncryptedImages(
    AppSettings settings,
    int loadGeneration,
  ) async {
    try {
      await _imageFeedService.loadFeedProgressively(
        settings: settings,
        onUpdate: (
          List<DeviceEncryptedImageFeedSection> sections,
          bool isComplete,
        ) {
          if (!mounted || loadGeneration != _imageLoadGeneration) {
            return;
          }

          setState(() {
            _imageSections = sections;
            _isLoadingImages = !isComplete;
            _imageErrorMessage = null;
          });
        },
      );
    } on ApiException catch (error) {
      if (!mounted || loadGeneration != _imageLoadGeneration) {
        return;
      }
      setState(() {
        _isLoadingImages = false;
        _imageErrorMessage = error.message;
      });
    } catch (error) {
      if (!mounted || loadGeneration != _imageLoadGeneration) {
        return;
      }
      setState(() {
        _isLoadingImages = false;
        _imageErrorMessage = error.toString();
      });
    }
  }

  Future<void> _openCaptureGroupSelection() async {
    final AppSettings settings = await _settingsStore.load();
    final String baseUrl = settings.managerServerURL?.trim() ?? '';
    if (!mounted) {
      return;
    }

    if (baseUrl.isEmpty) {
      ScreenFeedback.showMessage(context, 'Manager server URL is not set.');
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            widget.captureGroupPageBuilder?.call(context, baseUrl) ??
            SelectCaptureGroupPage(
              baseUrl: baseUrl,
            ),
      ),
    );
  }

  Future<void> _openGroups() async {
    final AppSettings settings = await _settingsStore.load();
    if (!mounted) {
      return;
    }

    if (settings.organizations.isEmpty) {
      final bool? added = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (BuildContext context) =>
              widget.addOrganizationPageBuilder?.call(context) ??
              const AddOrganizationPage(),
        ),
      );

      if (!mounted) {
        return;
      }

      if (added != true) {
        return;
      }

      final AppSettings updatedSettings = await _settingsStore.load();
      if (updatedSettings.managerModeEnabled &&
          (updatedSettings.managerServerURL?.trim().isEmpty ?? true) &&
          updatedSettings.organizations.length == 1) {
        await _settingsStore.saveManagerServerURL(
          updatedSettings.organizations.first.apiUrl,
        );
      }

      if (!mounted) {
        return;
      }
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            widget.groupsPageBuilder?.call(context) ?? const GroupsPage(),
      ),
    );

    if (!mounted) {
      return;
    }
    await _loadSettings();
  }

  bool get _canSendGroupNotifications => _canTakePictures;

  bool _sectionHasImages(DeviceEncryptedImageFeedSection section) {
    return section.days.any(
      (DeviceEncryptedImageFeedDay day) => day.items.isNotEmpty,
    );
  }

  String? _sectionBaseUrl(DeviceEncryptedImageFeedSection section) {
    for (final DeviceEncryptedImageFeedDay day in section.days) {
      for (final DeviceEncryptedImageFeedItem item in day.items) {
        final String? baseUrl = item.baseUrl?.trim();
        if (baseUrl != null && baseUrl.isNotEmpty) {
          return baseUrl;
        }
      }
    }
    return null;
  }

  Future<void> _openGroupNotificationPage(
    DeviceEncryptedImageFeedSection section,
  ) async {
    final String? baseUrl = _sectionBaseUrl(section);
    if (baseUrl == null || baseUrl.isEmpty) {
      ScreenFeedback.showMessage(
        context,
        'This group cannot be notified until its images finish loading.',
      );
      return;
    }

    final GroupNotificationResult? result =
        await Navigator.of(context).push<GroupNotificationResult>(
          MaterialPageRoute<GroupNotificationResult>(
            builder: (BuildContext context) => GroupPushNotificationPage(
              groupId: section.groupId,
              groupName: section.groupName,
              baseUrl: baseUrl,
            ),
          ),
        );
    if (!mounted || result == null) {
      return;
    }

    final String message = result.skippedCount > 0
        ? 'Notification sent to ${result.notifiedCount} devices. ${result.skippedCount} were skipped.'
        : 'Notification sent to ${result.notifiedCount} devices.';
    ScreenFeedback.showMessage(context, message);
  }

  Future<bool> _deleteImage(DeviceEncryptedImageFeedItem item) async {
    try {
      await _imageFeedService.deleteImage(item: item);
      if (!mounted) {
        return true;
      }

      setState(() {
        _imageSections = _removeImageFromSections(_imageSections, item.imageUuid);
      });
      ScreenFeedback.showMessage(context, 'Image deleted.');
      return true;
    } on ApiException catch (error) {
      if (mounted) {
        ScreenFeedback.showError(context, error);
      }
      return false;
    } catch (error) {
      if (mounted) {
        ScreenFeedback.showError(context, error);
      }
      return false;
    }
  }

  List<DeviceEncryptedImageFeedSection> _removeImageFromSections(
    List<DeviceEncryptedImageFeedSection> sections,
    String imageUuid,
  ) {
    final List<DeviceEncryptedImageFeedSection> updatedSections =
        <DeviceEncryptedImageFeedSection>[];

    for (final DeviceEncryptedImageFeedSection section in sections) {
      final List<DeviceEncryptedImageFeedDay> updatedDays =
          <DeviceEncryptedImageFeedDay>[];
      for (final DeviceEncryptedImageFeedDay day in section.days) {
        final List<DeviceEncryptedImageFeedItem> updatedItems = day.items
            .where((DeviceEncryptedImageFeedItem item) => item.imageUuid != imageUuid)
            .toList();
        if (updatedItems.isEmpty) {
          continue;
        }
        updatedDays.add(day.copyWith(items: updatedItems));
      }

      if (updatedDays.isEmpty) {
        continue;
      }
      updatedSections.add(section.copyWith(days: updatedDays));
    }

    return updatedSections;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Menu',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  if (_lastLoggedInUsername != null &&
                      _lastLoggedInUsername!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _lastLoggedInUsername!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photos'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Groups'),
              onTap: () async {
                Navigator.pop(context);
                await _openGroups();
              },
            ),
            if (_managerModeEnabled &&
                _lastLoggedInUsername != null &&
                _lastLoggedInUsername!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.account_circle),
                title: const Text('Account'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          AccountPage(username: _lastLoggedInUsername),
                    ),
                  ).then((_) => _loadSettings());
                },
              ),
            if (_managerModeEnabled &&
                (_lastLoggedInUsername == null ||
                    _lastLoggedInUsername!.isEmpty))
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Log In'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const LoginPage(),
                    ),
                  ).then((_) => _loadSettings());
                },
              ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const SettingsPage(),
                  ),
                ).then((_) {
                  widget.onSettingsChanged?.call();
                  _loadSettings();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const AboutPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: _canTakePictures
          ? FloatingActionButton(
              onPressed: _openCaptureGroupSelection,
              tooltip: 'Take Picture',
              child: const Icon(Icons.camera_alt),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadSettings,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isCheckingGroupMembership) {
      return _buildCenteredScrollable(
        context,
        const CircularProgressIndicator(),
      );
    }

    if (_imageSections.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final DeviceEncryptedImageFeedSection section in _imageSections) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    section.groupName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (_canSendGroupNotifications && _sectionHasImages(section))
                  IconButton(
                    onPressed: () => _openGroupNotificationPage(section),
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: 'Send Message to Group',
                  ),
              ],
            ),
            if (section.organizationName.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Text(
                  section.organizationName,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            for (final DeviceEncryptedImageFeedDay day in section.days) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  _formatDay(day.day),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 3 / 4,
                ),
                itemCount: day.items.length,
                itemBuilder: (BuildContext context, int index) {
                  return _EncryptedImageCard(
                    item: day.items[index],
                    dayItems: day.items,
                    initialIndex: index,
                    onDeleteRequested: _deleteImage,
                  );
                },
              ),
            ],
            const SizedBox(height: 24),
          ],
        ],
      );
    }

    if (_isInGroup == true) {
      if (_isLoadingImages) {
        return _buildImageLoadingPlaceholder(context);
      }

      if (_imageErrorMessage != null) {
        return _buildCenteredScrollable(
          context,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _imageErrorMessage!,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loadSettings,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }

      if (_imageSections.isEmpty) {
        return _buildCenteredScrollable(
          context,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Currently there are no images for you',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
    }

    if (_isInGroup == false) {
      return _buildCenteredScrollable(
        context,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _noGroupsYetMessage,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _openGroups(),
                child: const Text('Join Group'),
              ),
            ],
          ),
        ),
      );
    }

    return _buildCenteredScrollable(
      context,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _startupErrorMessage ??
                  'Could not reach the API. Please check your connection and try again.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadSettings,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenteredScrollable(BuildContext context, Widget child) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: child),
            ),
          ],
        );
      },
    );
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

  Widget _buildImageLoadingPlaceholder(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Loading images...',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 3 / 4,
          ),
          itemCount: 4,
          itemBuilder: (BuildContext context, int index) {
            return const _ImageLoadingCard();
          },
        ),
      ],
    );
  }

  String _formatDay(DateTime? day) {
    if (day == null) {
      return 'Unknown day';
    }
    final DateTime localDay = day.toLocal();
    const List<String> monthNames = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${monthNames[localDay.month - 1]} ${localDay.day}, ${localDay.year}';
  }
}

class _EncryptedImageCard extends StatelessWidget {
  const _EncryptedImageCard({
    required this.item,
    required this.dayItems,
    required this.initialIndex,
    this.onDeleteRequested,
  });

  final DeviceEncryptedImageFeedItem item;
  final List<DeviceEncryptedImageFeedItem> dayItems;
  final int initialIndex;
  final Future<bool> Function(DeviceEncryptedImageFeedItem item)? onDeleteRequested;

  void _openFullscreenImage(BuildContext context) {
    if (item.isCorrupt || item.imageBytes == null) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (BuildContext context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.transparent,
          child: _FullscreenImageViewer(
            items: dayItems,
            initialIndex: initialIndex,
            onDeleteRequested: onDeleteRequested,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget imageWidget = item.isLoading
        ? const _SkeletonShimmer()
        : item.isCorrupt || item.imageBytes == null
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 40,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to decrypt image',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        : Image.memory(
            item.imageBytes!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (
              BuildContext context,
              Object error,
              StackTrace? stackTrace,
            ) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          size: 40,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to decrypt image',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );

    return GestureDetector(
      onTap: item.isLoading || item.isCorrupt || item.imageBytes == null
          ? null
          : () => _openFullscreenImage(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageWidget,
            if (item.caption != null && item.caption!.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                    child: Text(
                      item.caption!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonShimmer extends StatefulWidget {
  const _SkeletonShimmer();

  @override
  State<_SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<_SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final Color highlightColor = Theme.of(context).colorScheme.surfaceContainerHigh;

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double travel = (_controller.value * 2.4) - 1.2;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.6 + travel, -0.25),
              end: Alignment(-0.4 + travel, 0.25),
              colors: <Color>[
                baseColor,
                baseColor,
                highlightColor,
                baseColor,
                baseColor,
              ],
              stops: const <double>[0.0, 0.28, 0.5, 0.72, 1.0],
            ),
          ),
          child: child,
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: baseColor.withValues(alpha: 0.28),
        ),
      ),
    );
  }
}

class _ImageLoadingCard extends StatelessWidget {
  const _ImageLoadingCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: const _SkeletonShimmer(),
    );
  }
}

class _FullscreenImageViewer extends StatefulWidget {
  const _FullscreenImageViewer({
    required this.items,
    required this.initialIndex,
    this.onDeleteRequested,
  });

  final List<DeviceEncryptedImageFeedItem> items;
  final int initialIndex;
  final Future<bool> Function(DeviceEncryptedImageFeedItem item)? onDeleteRequested;

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _showCaptionOverlay = true;
  bool _isDeleting = false;

  DeviceEncryptedImageFeedItem get _currentItem => widget.items[_currentIndex];

  void _toggleCaptionOverlay() {
    final String caption = _currentItem.caption?.trim() ?? '';
    if (caption.isEmpty) {
      return;
    }

    setState(() {
      _showCaptionOverlay = !_showCaptionOverlay;
    });
  }

  Future<void> _confirmDeleteCurrentImage() async {
    final DeviceEncryptedImageFeedItem currentItem = _currentItem;
    if (_isDeleting || !currentItem.canDelete || widget.onDeleteRequested == null) {
      return;
    }

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Image'),
          content: const Text(
            'Delete this image from the server for this group? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    final bool deleted = await widget.onDeleteRequested!(currentItem);
    if (!mounted) {
      return;
    }

    setState(() {
      _isDeleting = false;
    });

    if (deleted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _showCaptionOverlay = _currentItem.caption?.trim().isNotEmpty ?? false;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.items.length,
            onPageChanged: (int index) {
              setState(() {
                _currentIndex = index;
                _showCaptionOverlay =
                    widget.items[index].caption?.trim().isNotEmpty ?? false;
              });
            },
            itemBuilder: (BuildContext context, int index) {
              final DeviceEncryptedImageFeedItem item = widget.items[index];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: index == _currentIndex ? _toggleCaptionOverlay : null,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: item.isCorrupt || item.imageBytes == null
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.broken_image_outlined,
                                  size: 72,
                                  color: Colors.white70,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Failed to decrypt image',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : Image.memory(
                            item.imageBytes!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_currentItem.caption?.trim().isNotEmpty ?? false) ...[
          if (_showCaptionOverlay)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 12, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            onPressed: _toggleCaptionOverlay,
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white,
                            ),
                            tooltip: 'Collapse caption',
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: SingleChildScrollView(
                            child: Text(
                              _currentItem.caption!.trim(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Positioned(
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    onPressed: _toggleCaptionOverlay,
                    icon: const Icon(
                      Icons.keyboard_arrow_up,
                      color: Colors.white,
                    ),
                    tooltip: 'Show caption',
                  ),
                ),
              ),
            ),
        ],
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_currentIndex + 1} / ${widget.items.length}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.white),
                  ),
                ),
                if (_currentItem.canDelete && widget.onDeleteRequested != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton.filled(
                      onPressed: _isDeleting ? null : _confirmDeleteCurrentImage,
                      icon: _isDeleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline),
                      tooltip: 'Delete image',
                    ),
                  ),
                IconButton.filled(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
