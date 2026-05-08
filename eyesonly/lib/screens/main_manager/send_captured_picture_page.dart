import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:eyesonly/services/api_exception.dart';
import 'package:eyesonly/services/manager/encrypted_media_upload_service.dart';
import 'package:eyesonly/services/screen_feedback.dart';

class SendCapturedPicturePage extends StatefulWidget {
  const SendCapturedPicturePage({
    super.key,
    required this.baseUrl,
    required this.groupId,
    required this.groupName,
    required this.imageBytes,
  });

  final String baseUrl;
  final String groupId;
  final String groupName;
  final Uint8List imageBytes;

  @override
  State<SendCapturedPicturePage> createState() => _SendCapturedPicturePageState();
}

class _SendCapturedPicturePageState extends State<SendCapturedPicturePage> {
  final TextEditingController _captionController = TextEditingController();
  final EncryptedMediaUploadService _uploadService =
      EncryptedMediaUploadService();

  bool _isSending = false;

  void _deletePicture() {
    Navigator.of(context).pop(true);
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
      );

      if (!mounted) {
        return;
      }

      ScreenFeedback.showMessage(
        context,
        'Encrypted image sent to ${response.recipientCount} devices.',
      );
      Navigator.of(context).pop(false);
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
          _isSending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send')),
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
                decoration: const InputDecoration(
                  labelText: 'Add text',
                  hintText: 'Add optional text for this image',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _deletePicture,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                  const Spacer(),
                      FilledButton.icon(
                        onPressed: _isSending ? null : _send,
                        icon: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: Text(_isSending ? 'Sending...' : 'Send'),
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