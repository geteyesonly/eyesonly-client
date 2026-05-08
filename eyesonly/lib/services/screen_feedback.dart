import 'package:flutter/material.dart';

import 'package:eyesonly/services/api_exception.dart';

class ScreenFeedback {
  ScreenFeedback._();

  static void showMessage(BuildContext context, String message) {
    final String normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) {
      return;
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(normalizedMessage)),
    );
  }

  static void showError(
    BuildContext context,
    Object error, {
    String? fallbackMessage,
  }) {
    if (error is ApiException) {
      showMessage(context, error.message);
      return;
    }

    final String normalizedFallback = fallbackMessage?.trim() ?? '';
    if (normalizedFallback.isNotEmpty) {
      showMessage(context, normalizedFallback);
      return;
    }

    showMessage(context, error.toString());
  }
}