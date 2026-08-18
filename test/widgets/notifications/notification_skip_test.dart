import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/skipped_occurrence.dart';
import 'package:ezanvakti/presentation/widgets/notifications/notification_tile.dart';
import 'package:ezanvakti/presentation/widgets/reminders/notifications_section.dart';
import 'package:ezanvakti/presentation/services/upcoming_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  const dhuhr = NotificationSetting(
    prayerType: PrayerType.dhuhr,
    isActive: true,
    minutesBefore: 0,
  );
  final fireAt = DateTime(2026, 8, 19, 13, 0);

  group('NotificationTile', () {
    Widget build({
      bool isSkipped = false,
      DateTime? nextFireAt,
      VoidCallback? onSkipToggle,
    }) => wrapWithTheme(
      NotificationTile(
        setting: dhuhr,
        hasPermission: true,
        nextFireAt: nextFireAt ?? fireAt,
        isSkipped: isSkipped,
        onSkipToggle: onSkipToggle ?? () {},
      ),
    );

    testWidgets('Atlama eylemi gorunur', (tester) async {
      await tester.pumpWidget(build());
      expect(find.text('Bu seferi atla'), findsOneWidget);
    });

    testWidgets('Atlanmissa metin ve eylem tersine doner', (tester) async {
      await tester.pumpWidget(build(isSkipped: true));
      expect(find.text('Yalnızca bu sefer atlanacak'), findsOneWidget);
      expect(find.text('Geri al'), findsOneWidget);
    });

    testWidgets('Dokunmak yukari bildirir', (tester) async {
      var tapped = false;
      await tester.pumpWidget(build(onSkipToggle: () => tapped = true));
      await tester.tap(find.text('Bu seferi atla'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('Sonraki calma bilinmiyorsa eylem cizilmez', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const NotificationTile(setting: dhuhr, hasPermission: true),
        ),
      );
      expect(find.text('Bu seferi atla'), findsNothing);
    });
  });

  group('NotificationsSection', () {
    testWidgets('Atlama dogru occurrence ile bildirilir', (tester) async {
      SkippedOccurrence? seen;
      var value = false;

      await tester.pumpWidget(
        wrapWithTheme(
          NotificationsSection(
            settings: const [dhuhr],
            hasPermission: true,
            exactAlarmAllowed: true,
            onRequestPermission: () async => true,
            onPermissionChanged: (_) {},
            onOpenExactAlarmSettings: () async {},
            onToggle: (_) {},
            onEdit: (_) {},
            onDelete: (_) async {},
            nextFireByNotification: {notificationKey(dhuhr): fireAt},
            onSkipChanged: (o, s) {
              seen = o;
              value = s;
            },
          ),
        ),
      );

      await tester.tap(find.text('Bu seferi atla'));
      await tester.pump();

      expect(seen?.kind, SkipKind.notification);
      expect(seen?.reference, notificationKey(dhuhr));
      expect(seen?.fireAt, fireAt);
      expect(value, isTrue);
    });
  });
}
