enum PhotoExpirationPreset {
  oneDay,
  threeDays,
  sevenDays,
  fourteenDays,
  oneMonth,
}

class PhotoExpirationOption {
  const PhotoExpirationOption({required this.preset, required this.label});

  final PhotoExpirationPreset preset;
  final String label;
}

const List<PhotoExpirationOption> photoExpirationOptions =
    <PhotoExpirationOption>[
      PhotoExpirationOption(
        preset: PhotoExpirationPreset.oneDay,
        label: '1 day',
      ),
      PhotoExpirationOption(
        preset: PhotoExpirationPreset.threeDays,
        label: '3 days',
      ),
      PhotoExpirationOption(
        preset: PhotoExpirationPreset.sevenDays,
        label: '7 days',
      ),
      PhotoExpirationOption(
        preset: PhotoExpirationPreset.fourteenDays,
        label: '14 days',
      ),
      PhotoExpirationOption(
        preset: PhotoExpirationPreset.oneMonth,
        label: '1 month',
      ),
    ];

class PhotoExpirationSelection {
  const PhotoExpirationSelection({required this.preset});

  const PhotoExpirationSelection.defaultSelection()
    : preset = PhotoExpirationPreset.fourteenDays;

  final PhotoExpirationPreset preset;

  DateTime? resolveExpiresAt(DateTime now) {
    switch (preset) {
      case PhotoExpirationPreset.oneDay:
        return now.add(const Duration(days: 1));
      case PhotoExpirationPreset.threeDays:
        return now.add(const Duration(days: 3));
      case PhotoExpirationPreset.sevenDays:
        return now.add(const Duration(days: 7));
      case PhotoExpirationPreset.fourteenDays:
        return now.add(const Duration(days: 14));
      case PhotoExpirationPreset.oneMonth:
        return now.add(const Duration(days: 30));
    }
  }

  PhotoExpirationSelection copyWith({PhotoExpirationPreset? preset}) {
    return PhotoExpirationSelection(preset: preset ?? this.preset);
  }
}

String formatPhotoExpirationText(
  DateTime expiresAt, {
  DateTime? now,
  String Function(int daysLeft) expiresInDaysTextBuilder =
      _defaultExpiresInDaysText,
  String expiredText = 'Expired',
}) {
  final DateTime currentTime = now ?? DateTime.now();
  final Duration remaining = expiresAt.difference(currentTime);

  if (remaining.inSeconds <= 0) {
    return expiredText;
  }

  final int daysLeft = (remaining.inSeconds / Duration.secondsPerDay).ceil();
  return expiresInDaysTextBuilder(daysLeft);
}

String _defaultExpiresInDaysText(int daysLeft) {
  if (daysLeft == 1) {
    return 'Expires in 1 day';
  }
  return 'Expires in $daysLeft days';
}