import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:eyesonly/l10n/app_localizations.dart';
import 'package:eyesonly/screens/main_manager/login_page.dart';

import 'package:eyesonly/services/api_exception.dart';
import 'package:eyesonly/services/manager/encrypted_media_upload_service.dart';
import 'package:eyesonly/services/photo_expiration.dart';
import 'package:eyesonly/services/screen_feedback.dart';
import 'package:eyesonly/services/settings_store.dart';

class SendCapturedPictureResult {
  const SendCapturedPictureResult({
    required this.shouldDelete,
    required this.expirationSelection,
  });

  final bool shouldDelete;
  final PhotoExpirationSelection expirationSelection;
}

class SendCapturedPicturePage extends StatefulWidget {
  const SendCapturedPicturePage({
    super.key,
    required this.baseUrl,
    required this.groupId,
    required this.groupName,
    required this.imageBytes,
    this.initialExpirationSelection =
        const PhotoExpirationSelection.defaultSelection(),
  });

  final String baseUrl;
  final String groupId;
  final String groupName;
  final Uint8List imageBytes;
  final PhotoExpirationSelection initialExpirationSelection;

  @override
  State<SendCapturedPicturePage> createState() =>
      _SendCapturedPicturePageState();
}

class _SendCapturedPicturePageState extends State<SendCapturedPicturePage> {
  final TextEditingController _captionController = TextEditingController();
  final EncryptedMediaUploadService _uploadService =
      EncryptedMediaUploadService();
  final SettingsStore _settingsStore = SettingsStore();

  bool _isSending = false;
  late PhotoExpirationSelection _expirationSelection;

  @override
  void initState() {
    super.initState();
    _expirationSelection = widget.initialExpirationSelection;
  }

  Future<void> _persistExpirationSelection(
    PhotoExpirationSelection selection,
  ) async {
    try {
      await _settingsStore.savePreferredPhotoExpirationSelection(selection);
    } catch (_) {
      // Best effort only. Sending still uses the in-memory selection.
    }
  }

  void _deletePicture() {
    Navigator.of(context).pop(
      SendCapturedPictureResult(
        shouldDelete: true,
        expirationSelection: _expirationSelection,
      ),
    );
  }

  Future<void> _send() async {
    if (_isSending) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSending = true;
    });

    try {
      final response = await _uploadService.uploadImageForGroup(
        baseUrl: widget.baseUrl,
        groupId: widget.groupId,
        imageBytes: widget.imageBytes,
        caption: _captionController.text,
        expiresAt: _expirationSelection.resolveExpiresAt(DateTime.now()),
      );

      if (!mounted) {
        return;
      }

      final AppLocalizations l10n = AppLocalizations.of(context)!;
      ScreenFeedback.showMessage(
        context,
        l10n.sendSuccess(response.recipientCount),
      );
      Navigator.of(context).pop(
        SendCapturedPictureResult(
          shouldDelete: false,
          expirationSelection: _expirationSelection,
        ),
      );
    } on ApiException catch (error) {
      if (_isSessionExpiredError(error)) {
        await _redirectToLoginForExpiredSession(error);
        return;
      }
      if (!mounted) {
        return;
      }
      ScreenFeedback.showError(context, error);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScreenFeedback.showError(
        context,
        error,
        fallbackMessage: AppLocalizations.of(context)!.sendFailedTryAgain,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  bool _isSessionExpiredError(ApiException error) {
    final String message = error.message.trim().toLowerCase();
    return error.statusCode == 401 ||
        message.contains('session has expired') ||
        message.contains('please log in again') ||
        message.contains('could not be authenticated with this server');
  }

  Future<void> _redirectToLoginForExpiredSession(ApiException error) async {
    await _settingsStore.saveLastLoggedInUsername(null);
    if (!mounted) {
      return;
    }
    ScreenFeedback.showError(context, error);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const LoginPage(),
      ),
      (Route<dynamic> route) => route.isFirst,
    );
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sendTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.groupName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      widget.imageBytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _captionController,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: l10n.sendAddTextLabel,
                  hintText: l10n.sendAddTextHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              _ExpirationSelector(
                selection: _expirationSelection,
                onChanged: (PhotoExpirationSelection nextSelection) {
                  setState(() {
                    _expirationSelection = nextSelection;
                  });
                  _persistExpirationSelection(nextSelection);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _deletePicture,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.sendDelete),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _isSending ? null : _send,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isSending ? l10n.sendSending : l10n.sendSend),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpirationSelector extends StatefulWidget {
  const _ExpirationSelector({required this.selection, required this.onChanged});

  final PhotoExpirationSelection selection;
  final ValueChanged<PhotoExpirationSelection> onChanged;

  @override
  State<_ExpirationSelector> createState() => _ExpirationSelectorState();
}

class _ExpirationSelectorState extends State<_ExpirationSelector> {
  List<PhotoExpirationOption> _localizedOptions(AppLocalizations l10n) {
    return <PhotoExpirationOption>[
      PhotoExpirationOption(
        preset: PhotoExpirationPreset.oneDay,
        label: l10n.expirationOneDay,
      ),
      PhotoExpirationOption(
        preset: PhotoExpirationPreset.threeDays,
        label: l10n.expirationThreeDays,
      ),
      PhotoExpirationOption(
        preset: PhotoExpirationPreset.sevenDays,
        label: l10n.expirationSevenDays,
      ),
      PhotoExpirationOption(
        preset: PhotoExpirationPreset.fourteenDays,
        label: l10n.expirationFourteenDays,
      ),
      PhotoExpirationOption(
        preset: PhotoExpirationPreset.oneMonth,
        label: l10n.expirationOneMonth,
      ),
    ];
  }

  void _showExpirationModal() {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.sendSelectExpirationTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _localizedOptions(l10n)
                  .map(
                    (PhotoExpirationOption option) => _optionRow(
                      context,
                      label: option.label,
                      isSelected: widget.selection.preset == option.preset,
                      onTap: () {
                        _selectPreset(option.preset);
                        Navigator.pop(context);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }

  void _selectPreset(PhotoExpirationPreset preset) {
    widget.onChanged(widget.selection.copyWith(preset: preset));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String summaryText = _summaryLine(widget.selection);
    return GestureDetector(
      onTap: _showExpirationModal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sendPhotoExpiration,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            summaryText,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: Theme.of(context).primaryColor,
              decorationThickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionRow(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.radio_button_checked,
                  size: 18,
                  color: Theme.of(context).primaryColor,
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.radio_button_unchecked, size: 18),
              ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _summaryLine(PhotoExpirationSelection selection) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final DateTime expiresAt = selection.resolveExpiresAt(DateTime.now())!;
    return formatPhotoExpirationText(
      expiresAt,
      expiresInDaysTextBuilder: l10n.expirationInDays,
      expiresInHoursTextBuilder: l10n.expirationInHours,
      expiredText: l10n.expirationExpired,
    );
  }
}
