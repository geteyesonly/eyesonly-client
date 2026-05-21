import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_exception.dart';
import 'crypto/eyes_only_crypto.dart';
import 'device/api_service.dart';
import 'group_display_service.dart';
import 'manager/device_registration_keys.dart';
import 'secure_encrypted_image_blob_cache.dart';
import 'settings_store.dart';

const String _mediaContentKeyEncryptionHkdfInfo =
    'eyesonly-media-content-key-encryption-v1';

class DeviceEncryptedImageFeedSection {
  const DeviceEncryptedImageFeedSection({
    required this.sectionId,
    required this.organizationName,
    required this.groupId,
    required this.groupName,
    required this.days,
  });

  final String sectionId;
  final String organizationName;
  final String groupId;
  final String groupName;
  final List<DeviceEncryptedImageFeedDay> days;

  DeviceEncryptedImageFeedSection copyWith({
    String? sectionId,
    String? organizationName,
    String? groupId,
    String? groupName,
    List<DeviceEncryptedImageFeedDay>? days,
  }) {
    return DeviceEncryptedImageFeedSection(
      sectionId: sectionId ?? this.sectionId,
      organizationName: organizationName ?? this.organizationName,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      days: days ?? this.days,
    );
  }
}

class DeviceEncryptedImageFeedDay {
  const DeviceEncryptedImageFeedDay({required this.day, required this.items});

  final DateTime? day;
  final List<DeviceEncryptedImageFeedItem> items;

  DeviceEncryptedImageFeedDay copyWith({
    DateTime? day,
    List<DeviceEncryptedImageFeedItem>? items,
  }) {
    return DeviceEncryptedImageFeedDay(
      day: day ?? this.day,
      items: items ?? this.items,
    );
  }
}

class DeviceEncryptedImageFeedItem {
  const DeviceEncryptedImageFeedItem({
    required this.imageUuid,
    required this.isCorrupt,
    this.isLoading = false,
    this.imageBytes,
    this.createdAt,
    this.caption,
    this.baseUrl,
    this.groupId,
    this.expiresAt,
  });

  final String imageUuid;
  final bool isCorrupt;
  final bool isLoading;
  final Uint8List? imageBytes;
  final DateTime? createdAt;
  final String? caption;
  final String? baseUrl;
  final String? groupId;
  final DateTime? expiresAt;

  bool get canDelete =>
      (baseUrl?.trim().isNotEmpty ?? false) &&
      (groupId?.trim().isNotEmpty ?? false);

  DeviceEncryptedImageFeedItem copyWith({
    String? imageUuid,
    bool? isCorrupt,
    bool? isLoading,
    Uint8List? imageBytes,
    DateTime? createdAt,
    String? caption,
    Object? baseUrl = _unsetValue,
    Object? groupId = _unsetValue,
    Object? expiresAt = _unsetValue,
  }) {
    return DeviceEncryptedImageFeedItem(
      imageUuid: imageUuid ?? this.imageUuid,
      isCorrupt: isCorrupt ?? this.isCorrupt,
      isLoading: isLoading ?? this.isLoading,
      imageBytes: imageBytes ?? this.imageBytes,
      createdAt: createdAt ?? this.createdAt,
      caption: caption ?? this.caption,
      baseUrl: identical(baseUrl, _unsetValue)
          ? this.baseUrl
          : baseUrl as String?,
      groupId: identical(groupId, _unsetValue)
          ? this.groupId
          : groupId as String?,
      expiresAt: identical(expiresAt, _unsetValue)
          ? this.expiresAt
          : expiresAt as DateTime?,
    );
  }
}

const Object _unsetValue = Object();

class DeviceEncryptedImageFeedService {
  DeviceEncryptedImageFeedService({
    GroupDisplayService? groupDisplayService,
    SecureEncryptedImageBlobCache? imageCache,
    FlutterSecureStorage? secureStorage,
  }) : _groupDisplayService = groupDisplayService ?? GroupDisplayService(),
       _imageCache = imageCache,
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final GroupDisplayService _groupDisplayService;
    SecureEncryptedImageBlobCache? _imageCache;
  final FlutterSecureStorage _secureStorage;

    SecureEncryptedImageBlobCache get _resolvedImageCache =>
      _imageCache ??= SecureEncryptedImageBlobCache();

  Future<void> loadFeedProgressively({
    required AppSettings settings,
    required void Function(
      List<DeviceEncryptedImageFeedSection> sections,
      bool isComplete,
    )
    onUpdate,
  }) async {
    final List<_OrgSource> orgSources = settings.organizations.isNotEmpty
        ? settings.organizations
              .map(
                (AppOrganization organization) => _OrgSource(
                  organizationName: organization.name,
                  baseUrl: organization.apiUrl,
                ),
              )
              .toList()
        : settings.deviceServerURLs
              .map(
                (String url) => _OrgSource(organizationName: url, baseUrl: url),
              )
              .toList();

    List<DeviceEncryptedImageFeedSection> sections =
        <DeviceEncryptedImageFeedSection>[];
    final Set<String> activeImageUuids = <String>{};

    for (final _OrgSource source in orgSources) {
      final _ProgressiveOrganizationFeed progressiveFeed =
          await _prepareProgressiveFeedForOrganization(source);
      if (progressiveFeed.sections.isEmpty) {
        continue;
      }

      activeImageUuids.addAll(
        progressiveFeed.itemRefs.map(
          (_ProgressiveFeedItemRef itemRef) => itemRef.image.imageUuid,
        ),
      );

      sections = _sortSections(<DeviceEncryptedImageFeedSection>[
        ...sections,
        ...progressiveFeed.sections,
      ]);
      onUpdate(
        List<DeviceEncryptedImageFeedSection>.unmodifiable(sections),
        false,
      );

      for (final _ProgressiveFeedItemRef itemRef in progressiveFeed.itemRefs) {
        final DeviceEncryptedImageFeedItem item = await _buildFeedItem(
          deviceApiService: progressiveFeed.deviceApiService,
          image: itemRef.image,
          baseUrl: source.baseUrl,
          groupId: itemRef.groupId,
        );
        sections = _replaceFeedItem(
          sections: sections,
          sectionId: itemRef.sectionId,
          dayIndex: itemRef.dayIndex,
          itemIndex: itemRef.itemIndex,
          item: item,
        );
        onUpdate(
          List<DeviceEncryptedImageFeedSection>.unmodifiable(sections),
          false,
        );
      }
    }

    await _resolvedImageCache.pruneToActiveImageUuids(activeImageUuids);

    onUpdate(
      List<DeviceEncryptedImageFeedSection>.unmodifiable(sections),
      true,
    );
  }

  Future<List<DeviceEncryptedImageFeedSection>> loadFeed({
    required AppSettings settings,
  }) async {
    List<DeviceEncryptedImageFeedSection> sections =
        <DeviceEncryptedImageFeedSection>[];
    await loadFeedProgressively(
      settings: settings,
      onUpdate:
          (
            List<DeviceEncryptedImageFeedSection> nextSections,
            bool isComplete,
          ) {
            sections = nextSections;
          },
    );
    return sections;
  }

  Future<_ProgressiveOrganizationFeed> _prepareProgressiveFeedForOrganization(
    _OrgSource source,
  ) async {
    final DeviceApiService deviceApiService = DeviceApiService(
      baseUrl: source.baseUrl,
    );
    final List<DeviceGroup> groups = await deviceApiService.getGroups();
    final Map<String, DeviceGroup> groupsById = <String, DeviceGroup>{
      for (final DeviceGroup group in groups)
        if (group.uuid.trim().isNotEmpty) group.uuid.trim(): group,
    };

    await _groupDisplayService.syncGroupKeysFromDeviceEndpoint(
      baseUrl: source.baseUrl,
      groupIds: groupsById.keys,
    );

    final DeviceEncryptedImageListResponse response = await deviceApiService
        .getEncryptedImages(limit: 100);
    final List<DeviceEncryptedImageFeedSection> sections =
        <DeviceEncryptedImageFeedSection>[];
    final List<_ProgressiveFeedItemRef> itemRefs = <_ProgressiveFeedItemRef>[];

    for (final DeviceEncryptedImageGroup imageGroup in response.groups) {
      final DeviceGroup? group = groupsById[imageGroup.groupId];
      final String groupName = group == null
          ? 'Group ${imageGroup.groupId.substring(0, 8)}'
          : await _groupDisplayService.tryDecryptGroupName(
                  groupId: group.uuid,
                  encryptedName: group.encryptedName,
                  nameNonce: group.nameNonce,
                ) ??
                'Group ${imageGroup.groupId.substring(0, 8)}';

      final List<DeviceEncryptedImageFeedDay> days =
          <DeviceEncryptedImageFeedDay>[];
      final List<DeviceEncryptedImageDayGroup> sortedDayGroups =
          List<DeviceEncryptedImageDayGroup>.from(imageGroup.days)..sort(
            (DeviceEncryptedImageDayGroup a, DeviceEncryptedImageDayGroup b) =>
                (b.day ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
                  a.day ?? DateTime.fromMillisecondsSinceEpoch(0),
                ),
          );

      final String sectionId = '${source.baseUrl}::${imageGroup.groupId}';
      for (final DeviceEncryptedImageDayGroup dayGroup in sortedDayGroups) {
        final List<DeviceEncryptedImage> sortedImages =
            List<DeviceEncryptedImage>.from(dayGroup.images)..sort(
              (DeviceEncryptedImage a, DeviceEncryptedImage b) =>
                  (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                      .compareTo(
                        a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                      ),
            );
        if (sortedImages.isEmpty) {
          continue;
        }

        final int dayIndex = days.length;
        final List<DeviceEncryptedImageFeedItem> items =
            <DeviceEncryptedImageFeedItem>[];
        for (final DeviceEncryptedImage image in sortedImages) {
          final int itemIndex = items.length;
          items.add(
            DeviceEncryptedImageFeedItem(
              imageUuid: image.imageUuid,
              isCorrupt: false,
              isLoading: true,
              createdAt: image.createdAt,
              baseUrl: source.baseUrl,
              groupId: imageGroup.groupId,
              expiresAt: image.expiresAt,
            ),
          );
          itemRefs.add(
            _ProgressiveFeedItemRef(
              sectionId: sectionId,
              dayIndex: dayIndex,
              itemIndex: itemIndex,
              groupId: imageGroup.groupId,
              image: image,
            ),
          );
        }

        days.add(DeviceEncryptedImageFeedDay(day: dayGroup.day, items: items));
      }

      if (days.isEmpty) {
        continue;
      }

      sections.add(
        DeviceEncryptedImageFeedSection(
          sectionId: sectionId,
          organizationName: source.organizationName,
          groupId: imageGroup.groupId,
          groupName: groupName,
          days: days,
        ),
      );
    }

    return _ProgressiveOrganizationFeed(
      deviceApiService: deviceApiService,
      sections: sections,
      itemRefs: itemRefs,
    );
  }

  List<DeviceEncryptedImageFeedSection> _sortSections(
    List<DeviceEncryptedImageFeedSection> sections,
  ) {
    final List<DeviceEncryptedImageFeedSection> sortedSections =
        List<DeviceEncryptedImageFeedSection>.from(sections);
    sortedSections.sort((
      DeviceEncryptedImageFeedSection a,
      DeviceEncryptedImageFeedSection b,
    ) {
      final int orgComparison = a.organizationName.toLowerCase().compareTo(
        b.organizationName.toLowerCase(),
      );
      if (orgComparison != 0) {
        return orgComparison;
      }
      return a.groupName.toLowerCase().compareTo(b.groupName.toLowerCase());
    });
    return sortedSections;
  }

  List<DeviceEncryptedImageFeedSection> _replaceFeedItem({
    required List<DeviceEncryptedImageFeedSection> sections,
    required String sectionId,
    required int dayIndex,
    required int itemIndex,
    required DeviceEncryptedImageFeedItem item,
  }) {
    return sections.map((DeviceEncryptedImageFeedSection section) {
      if (section.sectionId != sectionId) {
        return section;
      }

      final List<DeviceEncryptedImageFeedDay> updatedDays =
          List<DeviceEncryptedImageFeedDay>.from(section.days);
      if (dayIndex < 0 || dayIndex >= updatedDays.length) {
        return section;
      }

      final DeviceEncryptedImageFeedDay targetDay = updatedDays[dayIndex];
      final List<DeviceEncryptedImageFeedItem> updatedItems =
          List<DeviceEncryptedImageFeedItem>.from(targetDay.items);
      if (itemIndex < 0 || itemIndex >= updatedItems.length) {
        return section;
      }

      updatedItems[itemIndex] = item.copyWith(isLoading: false);
      updatedDays[dayIndex] = targetDay.copyWith(items: updatedItems);
      return section.copyWith(days: updatedDays);
    }).toList();
  }

  Future<DeviceEncryptedImageFeedItem> _buildFeedItem({
    required DeviceApiService deviceApiService,
    required DeviceEncryptedImage image,
    required String baseUrl,
    required String groupId,
  }) async {
    String stage = 'unwrap-content-key';

    try {
      final List<int> contentKeyBytes = await _unwrapContentKey(
        image.encryptedContentKey,
      );

      Uint8List encryptedBytes;
      stage = 'cache-read';
        final SecureEncryptedImageBlobCacheEntry? cachedEntry =
          await _resolvedImageCache.read(image.imageUuid);
      if (cachedEntry != null) {
        _logImageFeedDebug(imageUuid: image.imageUuid, message: 'cache hit');
        encryptedBytes = cachedEntry.encryptedBlobBytes;
      } else {
        _logImageFeedDebug(imageUuid: image.imageUuid, message: 'cache miss');

        stage = 'download-image-blob';
        encryptedBytes = Uint8List.fromList(
          await deviceApiService.downloadEncryptedImageBlob(
            imageUuid: image.imageUuid,
          ),
        );

        stage = 'cache-write';
        try {
          await _resolvedImageCache.write(
            imageUuid: image.imageUuid,
            encryptedBlobBytes: encryptedBytes,
          );
        } catch (error) {
          // Cache writes are best effort. The fetched encrypted blob is still usable.
          _logImageFeedDebug(
            imageUuid: image.imageUuid,
            message: 'cache write failed: ${error.runtimeType}: $error',
          );
        }
      }

      stage = 'decrypt-image-payload';
      final List<int> decryptedBytes = await EyesOnlyCrypto.symmetricDecrypt(
        base64Encode(encryptedBytes),
        image.payloadNonce,
        contentKeyBytes,
      );

      stage = 'decrypt-caption';
      final String? caption = await _decryptCaption(
        image.encryptedCaption,
        contentKeyBytes,
      );

      final Uint8List decryptedImageBytes = Uint8List.fromList(decryptedBytes);

      _logImageFeedDebug(imageUuid: image.imageUuid, message: 'success');

      return DeviceEncryptedImageFeedItem(
        imageUuid: image.imageUuid,
        isCorrupt: false,
        imageBytes: decryptedImageBytes,
        createdAt: image.createdAt,
        caption: caption,
        baseUrl: baseUrl,
        groupId: groupId,
        expiresAt: image.expiresAt,
      );
    } catch (error, stackTrace) {
      _logImageFeedDebug(
        imageUuid: image.imageUuid,
        message: 'failed at $stage: ${error.runtimeType}: $error\n$stackTrace',
      );
      return DeviceEncryptedImageFeedItem(
        imageUuid: image.imageUuid,
        isCorrupt: true,
        createdAt: image.createdAt,
        baseUrl: baseUrl,
        groupId: groupId,
        expiresAt: image.expiresAt,
      );
    }
  }

  Future<void> deleteImage({required DeviceEncryptedImageFeedItem item}) async {
    final String baseUrl = item.baseUrl?.trim() ?? '';
    final String groupId = item.groupId?.trim() ?? '';
    if (baseUrl.isEmpty || groupId.isEmpty) {
      throw ApiException('Image metadata is not available for deletion.');
    }

    final DeviceApiService deviceApiService = DeviceApiService(
      baseUrl: baseUrl,
    );
    await deviceApiService.deleteEncryptedImage(
      groupId: groupId,
      imageUuid: item.imageUuid,
    );
    await _resolvedImageCache.remove(item.imageUuid);
  }

  Future<List<int>> _unwrapContentKey(String encryptedContentKey) async {
    final String? privateKeyB64 = await _secureStorage.read(
      key: DeviceRegistrationKeys.privateKey,
    );
    final String? publicKeyB64 = await _secureStorage.read(
      key: DeviceRegistrationKeys.publicKey,
    );
    if (privateKeyB64 == null ||
        privateKeyB64.isEmpty ||
        publicKeyB64 == null ||
        publicKeyB64.isEmpty) {
      throw ApiException(
        'Device key material is not available for image decryption.',
      );
    }

    return EyesOnlyCrypto.unwrapWithPrivateKey(
      encryptedContentKey,
      base64Decode(privateKeyB64),
      base64Decode(publicKeyB64),
      _mediaContentKeyEncryptionHkdfInfo,
    );
  }

  Future<String?> _decryptCaption(
    String? encryptedCaption,
    List<int> contentKeyBytes,
  ) async {
    final String normalizedCaption = encryptedCaption?.trim() ?? '';
    if (normalizedCaption.isEmpty) {
      return null;
    }

    try {
      final dynamic decoded = jsonDecode(
        utf8.decode(base64Decode(normalizedCaption)),
      );
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final String ciphertext =
          (decoded['ciphertext'] as String?)?.trim() ?? '';
      final String nonce = (decoded['nonce'] as String?)?.trim() ?? '';
      if (ciphertext.isEmpty || nonce.isEmpty) {
        return null;
      }

      final List<int> plainBytes = await EyesOnlyCrypto.symmetricDecrypt(
        ciphertext,
        nonce,
        contentKeyBytes,
      );
      final String caption = utf8.decode(plainBytes).trim();
      return caption.isEmpty ? null : caption;
    } catch (_) {
      return null;
    }
  }

  void _logImageFeedDebug({
    required String imageUuid,
    required String message,
  }) {
    if (!kDebugMode) {
      return;
    }

    final String shortId = imageUuid.length <= 8
        ? imageUuid
        : imageUuid.substring(0, 8);
    debugPrint('[ImageFeed:$shortId] $message');
  }
}

class _OrgSource {
  const _OrgSource({required this.organizationName, required this.baseUrl});

  final String organizationName;
  final String baseUrl;
}

class _ProgressiveOrganizationFeed {
  const _ProgressiveOrganizationFeed({
    required this.deviceApiService,
    required this.sections,
    required this.itemRefs,
  });

  final DeviceApiService deviceApiService;
  final List<DeviceEncryptedImageFeedSection> sections;
  final List<_ProgressiveFeedItemRef> itemRefs;
}

class _ProgressiveFeedItemRef {
  const _ProgressiveFeedItemRef({
    required this.sectionId,
    required this.dayIndex,
    required this.itemIndex,
    required this.groupId,
    required this.image,
  });

  final String sectionId;
  final int dayIndex;
  final int itemIndex;
  final String groupId;
  final DeviceEncryptedImage image;
}
