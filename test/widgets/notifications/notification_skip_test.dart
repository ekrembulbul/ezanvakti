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

    bool switchValue(WidgetTester tester) =>
        tester.widget<Switch>(find.byType(Switch)).value;

    testWidgets('Satirda ayri bir atlama eylemi yok', (tester) async {
      await tester.pumpWidget(build());
      // Atlama artik anahtar kapatilinca alttaki cubuktan seciliyor.
      expect(find.text('Bu seferi atla'), findsNothing);
      expect(switchValue(tester), isTrue);
    });

    testWidgets('Atlanan bildirim kapali gorunur', (tester) async {
      await tester.pumpWidget(build(isSkipped: true));
      expect(find.text('Yalnızca bu sefer atlanacak'), findsOneWidget);
      expect(
        switchValue(tester),
        isFalse,
        reason: 'kullanici icin atlanmis da kapali da "bu sefer gelmeyecek"',
      );
    });

    testWidgets('Kapali bildirimin alt metni "Kapalı"', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          NotificationTile(
            setting: dhuhr.copyWith(isActive: false),
            hasPermission: true,
            nextFireAt: fireAt,
          ),
        ),
      );
      expect(find.text('Kapalı'), findsOneWidget);
    });

    testWidgets('Atlanan bildirimi acmak atlamayi kaldirir', (tester) async {
      var unskipped = false;
      var toggled = false;
      await tester.pumpWidget(
        wrapWithTheme(
          NotificationTile(
            setting: dhuhr,
            hasPermission: true,
            nextFireAt: fireAt,
            isSkipped: true,
            onSkipToggle: () => unskipped = true,
            onToggle: () => toggled = true,
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(unskipped, isTrue);
      expect(
        toggled,
        isFalse,
        reason: 'bildirim zaten aktif; ayrica acilmaya calisilmamali',
      );
    });

    testWidgets('Sonraki calma bilinmiyorsa atlama durumu cizilmez', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const NotificationTile(
            setting: dhuhr,
            hasPermission: true,
            isSkipped: true,
          ),
        ),
      );
      expect(find.text('Yalnızca bu sefer atlanacak'), findsNothing);
      expect(switchValue(tester), isTrue);
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
            skips: {
              SkippedOccurrence(
                kind: SkipKind.notification,
                reference: notificationKey(dhuhr),
                fireAt: fireAt,
              ),
            },
            onSkipChanged: (o, s) {
              seen = o;
              value = s;
            },
          ),
        ),
      );

      // Atlanmis satirin anahtari acilinca atlama kalkar; occurrence bu
      // yoldan bildiriliyor.
      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(seen?.kind, SkipKind.notification);
      expect(seen?.reference, notificationKey(dhuhr));
      expect(seen?.fireAt, fireAt);
      expect(value, isFalse);
    });
  });
}
