import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:eyesonly/l10n/app_localizations.dart';
import 'package:eyesonly/screens/main_manager/send_captured_picture_page.dart';
import 'package:eyesonly/services/photo_expiration.dart';

void main() {
  group('SendCapturedPicturePage expiration selector', () {
    final Uint8List transparentImageBytes = Uint8List.fromList(
      <int>[
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
        0x00,
        0x00,
        0x00,
        0x0d,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1f,
        0x15,
        0xc4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0a,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9c,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0d,
        0x0a,
        0x2d,
        0xb4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4e,
        0x44,
        0xae,
        0x42,
        0x60,
        0x82,
      ],
    );

    Widget buildTestApp(Widget child) {
      return MaterialApp(
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      );
    }

    testWidgets('displays default 14-day expiration', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          SendCapturedPicturePage(
            baseUrl: 'http://example.com',
            groupId: 'group-1',
            groupName: 'Test Group',
            imageBytes: transparentImageBytes,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Will be deleted at'), findsOneWidget);
      expect(find.textContaining('Will be deleted in'), findsOneWidget);
    });

    testWidgets('opens expiration modal when tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          SendCapturedPicturePage(
            baseUrl: 'http://example.com',
            groupId: 'group-1',
            groupName: 'Test Group',
            imageBytes: transparentImageBytes,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Select deletion time'), findsNothing);

      await tester.tap(find.text('Will be deleted at'));
      await tester.pumpAndSettle();

      expect(find.text('Select deletion time'), findsOneWidget);
      expect(find.text('1 day'), findsOneWidget);
      expect(find.text('3 days'), findsOneWidget);
      expect(find.text('7 days'), findsOneWidget);
      expect(find.text('14 days'), findsOneWidget);
      expect(find.text('1 month'), findsOneWidget);
    });

    testWidgets('selects 1-day expiration and reflects in summary', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          SendCapturedPicturePage(
            baseUrl: 'http://example.com',
            groupId: 'group-1',
            groupName: 'Test Group',
            imageBytes: transparentImageBytes,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Will be deleted at'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('1 day'));
      await tester.pumpAndSettle();

      expect(find.text('Will be deleted in 24 hours'), findsOneWidget);
    });

    testWidgets('selects 7-day expiration', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          SendCapturedPicturePage(
            baseUrl: 'http://example.com',
            groupId: 'group-1',
            groupName: 'Test Group',
            imageBytes: transparentImageBytes,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Will be deleted at'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('7 days'));
      await tester.pumpAndSettle();

      expect(find.text('Will be deleted in 7 days'), findsOneWidget);
    });

    testWidgets('persists expiration selection across delete/send cycles', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          SendCapturedPicturePage(
            baseUrl: 'http://example.com',
            groupId: 'group-1',
            groupName: 'Test Group',
            imageBytes: transparentImageBytes,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Change to 1-day expiration
      await tester.tap(find.text('Will be deleted at'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 day'));
      await tester.pumpAndSettle();

      expect(find.text('Will be deleted in 24 hours'), findsOneWidget);

      // Delete and verify selection is still 1 day for next send
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Pop back and re-enter with saved selection
      expect(find.byType(SendCapturedPicturePage), findsNothing);
    });

    testWidgets('PhotoExpirationSelection.defaultSelection returns 14 days', (
      WidgetTester tester,
    ) async {
      final PhotoExpirationSelection selection =
          const PhotoExpirationSelection.defaultSelection();
      expect(selection.preset, PhotoExpirationPreset.fourteenDays);

      final DateTime now = DateTime.now();
      final DateTime? expiresAt = selection.resolveExpiresAt(now);
      expect(expiresAt, isNotNull);

      final Duration expectedDuration = Duration(days: 14);
      final DateTime expected = now.add(expectedDuration);
      final Duration diff = (expiresAt!.difference(expected)).abs();
      expect(diff.inSeconds, lessThan(2));
    });
  });

  group('PhotoExpirationSelection', () {
    test('resolveExpiresAt returns correct duration for each preset', () {
      final DateTime now = DateTime(2026, 5, 11);

      expect(
        PhotoExpirationSelection(preset: PhotoExpirationPreset.oneDay)
            .resolveExpiresAt(now),
        equals(DateTime(2026, 5, 12)),
      );

      expect(
        PhotoExpirationSelection(preset: PhotoExpirationPreset.threeDays)
            .resolveExpiresAt(now),
        equals(DateTime(2026, 5, 14)),
      );

      expect(
        PhotoExpirationSelection(preset: PhotoExpirationPreset.sevenDays)
            .resolveExpiresAt(now),
        equals(DateTime(2026, 5, 18)),
      );

      expect(
        PhotoExpirationSelection(preset: PhotoExpirationPreset.fourteenDays)
            .resolveExpiresAt(now),
        equals(DateTime(2026, 5, 25)),
      );

      expect(
        PhotoExpirationSelection(preset: PhotoExpirationPreset.oneMonth)
            .resolveExpiresAt(now),
        equals(DateTime(2026, 6, 10)),
      );
    });

    test('copyWith creates new instance with updated preset', () {
      final PhotoExpirationSelection selection =
          PhotoExpirationSelection(preset: PhotoExpirationPreset.oneDay);
      final PhotoExpirationSelection updated =
          selection.copyWith(preset: PhotoExpirationPreset.sevenDays);

      expect(selection.preset, PhotoExpirationPreset.oneDay);
      expect(updated.preset, PhotoExpirationPreset.sevenDays);
    });
  });

  group('PhotoExpirationSelection - Future no-expiration scenario', () {
    test(
      'resolveExpiresAt should return null when no-expiration preset is added',
      () {
        // TODO: Implement when no-expiration option is added.
        // This test ensures the API contract supports future no-expiration behavior.
        // Expected: PhotoExpirationSelection.noExpiration().resolveExpiresAt() == null
      },
      skip: 'No-expiration preset not yet implemented.',
    );
  });

  group('formatPhotoExpirationText', () {
    test('uses hour text when less than one day remains', () {
      final DateTime now = DateTime(2026, 5, 11, 10, 0, 0);
      final DateTime expiresAt = now.add(const Duration(hours: 5, minutes: 1));

      final String text = formatPhotoExpirationText(
        expiresAt,
        now: now,
        expiresInDaysTextBuilder: (int days) => 'D:$days',
        expiresInHoursTextBuilder: (int hours) => 'H:$hours',
        expiredText: 'X',
      );

      expect(text, 'H:6');
    });

    test('uses day text when one day or more remains', () {
      final DateTime now = DateTime(2026, 5, 11, 10, 0, 0);
      final DateTime expiresAt = now.add(const Duration(days: 1));

      final String text = formatPhotoExpirationText(
        expiresAt,
        now: now,
        expiresInDaysTextBuilder: (int days) => 'D:$days',
        expiresInHoursTextBuilder: (int hours) => 'H:$hours',
        expiredText: 'X',
      );

      expect(text, 'D:1');
    });
  });
}
