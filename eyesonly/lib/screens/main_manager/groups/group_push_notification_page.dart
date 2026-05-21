import 'package:flutter/material.dart';

import 'package:eyesonly/l10n/app_localizations.dart';
import 'package:eyesonly/services/api_exception.dart';
import 'package:eyesonly/services/manager/group_notification_service.dart';
import 'package:eyesonly/services/screen_feedback.dart';

class GroupPushNotificationPage extends StatefulWidget {
  const GroupPushNotificationPage({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.baseUrl,
    this.groupNotificationService,
  });

  final String groupId;
  final String groupName;
  final String baseUrl;
  final GroupNotificationService? groupNotificationService;

  @override
  State<GroupPushNotificationPage> createState() =>
      _GroupPushNotificationPageState();
}

class _GroupPushNotificationPageState extends State<GroupPushNotificationPage> {
  late final GroupNotificationService _groupNotificationService;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _groupNotificationService =
        widget.groupNotificationService ?? GroupNotificationService();
  }

  Future<void> _send() async {
    setState(() {
      _isSending = true;
    });

    try {
      final GroupNotificationResult result =
          await _groupNotificationService.sendGroupNotification(
            baseUrl: widget.baseUrl,
            groupId: widget.groupId,
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(result);
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
  Widget build(BuildContext context) {
    final AppLocalizations? l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n?.homeSendMessageToGroup ?? 'Send Message to Group',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.groupPushFixedMessageIntro ??
                  'The notification message is fixed for privacy reasons:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                GroupNotificationService.fixedNotificationMessage,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _isSending ? null : _send,
                icon: _isSending
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(l10n?.sendSend ?? 'Send'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}