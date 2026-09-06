import 'package:ezanvakti/presentation/widgets/home/upcoming_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/skipped_occurrence.dart';
import 'package:ezanvakti/features/notifications/domain/notification_scheduler.dart';
import 'package:ezanvakti/presentation/services/upcoming_resolver.dart';

import '../theme_harness.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  group('UpcomingCard', () {
    final now = DateTime(2026, 8, 3, 17, 42);

    final notification = (
      setting: const NotificationSetting(
        prayerType: PrayerType.maghrib,
        isActive: true,
        minutesBefore: 10,
      ),
      prayerDate: DateTime(2026, 8, 3),
      time: DateTime(2026, 8, 3, 20, 15),
    );
    const sahur = Alarm(
      id: 'sahur',
      kind: AlarmKind.anchored,
      label: 'Sahur',
      anchor: PrayerType.fajr,
      offsetMinutes: -30,
    );
    final alarmAt = DateTime(2026, 8, 4, 3, 41);

    SkippedOccurrence notificationSkip() => SkippedOccurrence(
      kind: SkipKind.notification,
      reference: NotificationScheduler.notificationIdFor(
        date: notification.prayerDate,
        pointIndex: NotificationScheduler.pointIndexOf(notification.setting),
        minutesBefore: notification.setting.minutesBefore,
      ),
      fireAt: notification.time,
    );

    SkippedOccurrence alarmSkip() => SkippedOccurrence(
      kind: SkipKind.alarm,
      reference: sahur.id,
      fireAt: alarmAt,
    );

    Future<void> pumpCard(
      WidgetTester tester, {
      UpcomingNotification? notification,
      UpcomingAlarm? alarm,
      VoidCallback? onSeeAll,
      Set<SkippedOccurrence> skips = const {},
      void Function(SkippedOccurrence, bool)? onSkipChanged,
    }) async {
      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(
            width: 360,
            child: UpcomingCard(
              now: now,
              notification: notification,
              alarm: alarm,
              skips: skips,
              onSkipChanged: onSkipChanged,
              onSeeAll: onSeeAll ?? () {},
            ),
          ),
        ),
      );
    }

    testWidgets('SIRADAKI etiketi ve bos durum metni', (tester) async {
      await pumpCard(tester);

      expect(find.text('SIRADAKİ'), findsOneWidget);
      expect(find.text('Yaklaşan bildirim veya alarm yok'), findsOneWidget);
    });

    testWidgets('Tumu kisayoluna dokunmak callback cagirir', (tester) async {
      var tapped = false;

      await pumpCard(tester, onSeeAll: () => tapped = true);

      await tester.tap(find.text('Tümü'));
      expect(tapped, isTrue);
    });

    testWidgets('Bildirim satiri kalan sureyi alt metinde yazar', (
      tester,
    ) async {
      await pumpCard(tester, notification: notification);

      // Sag taraf tek islevli kaldi: kalan sure alt metne tasindi.
      expect(find.text('Akşam'), findsOneWidget);
      expect(find.text('10 dk önce · bugün 20:15 · 2s 33dk'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('Tam vaktinde bildirim sapma yazmaz', (tester) async {
      await pumpCard(
        tester,
        notification: (
          setting: const NotificationSetting(
            prayerType: PrayerType.isha,
            isActive: true,
          ),
          prayerDate: DateTime(2026, 8, 3),
          time: DateTime(2026, 8, 3, 22, 1),
        ),
      );

      expect(find.text('Tam vaktinde · bugün 22:01 · 4s 19dk'), findsOneWidget);
    });

    testWidgets(
      'Cuma bildirimi kullanıcının verdiği adı ve gerçek saatini gösterir',
      (tester) async {
        await pumpCard(
          tester,
          notification: (
            setting: const NotificationSetting(
              prayerType: PrayerType.dhuhr,
              isActive: true,
              minutesBefore: 45,
              weekdays: {5},
              label: 'Cuma namazı',
            ),
            prayerDate: DateTime(2026, 8, 7),
            time: DateTime(2026, 8, 7, 12, 17),
          ),
        );
        expect(find.text('Cuma namazı'), findsOneWidget);
        expect(find.text('Öğle bildirimi'), findsNothing);
        expect(find.textContaining('12:17'), findsOneWidget);
      },
    );

    testWidgets('Alarm satiri etiket, cipa ve gun yazar', (tester) async {
      await pumpCard(tester, alarm: (alarm: sahur, time: alarmAt));

      expect(find.text('Sahur'), findsOneWidget);
      expect(find.text('İmsak −30 dk · yarın 03:41'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('Adsız sabit alarm saati bir kez gösterilir', (tester) async {
      await pumpCard(
        tester,
        alarm: (
          alarm: const Alarm(
            id: 'fixed',
            kind: AlarmKind.fixed,
            hour: 19,
            minute: 42,
          ),
          time: DateTime(2026, 8, 3, 19, 42),
        ),
      );
      expect(find.textContaining('19:42'), findsOneWidget);
      expect(find.textContaining('2s 0dk'), findsOneWidget);
    });

    testWidgets('Atlanmis bildirim satiri yerinde kalir ve aciklanir', (
      tester,
    ) async {
      await pumpCard(
        tester,
        notification: notification,
        skips: {notificationSkip()},
      );

      // D2: kart bir sonrakine gecmez; satir kapali cizilir ki geri acilabilsin.
      expect(find.text('Akşam'), findsOneWidget);
      expect(find.text('Yalnızca bu sefer atlanacak · 20:15'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('Atlanmis alarm satiri yerinde kalir ve aciklanir', (
      tester,
    ) async {
      await pumpCard(
        tester,
        alarm: (alarm: sahur, time: alarmAt),
        skips: {alarmSkip()},
      );

      expect(find.text('Sahur'), findsOneWidget);
      expect(
        find.text('Yalnızca bu sefer atlanacak · yarın 03:41'),
        findsOneWidget,
      );
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('Anahtari kapatmak dogru kayitla callback tetikler', (
      tester,
    ) async {
      SkippedOccurrence? received;
      bool? skipped;

      await pumpCard(
        tester,
        alarm: (alarm: sahur, time: alarmAt),
        onSkipChanged: (occurrence, value) {
          received = occurrence;
          skipped = value;
        },
      );

      await tester.tap(find.byType(Switch));

      expect(skipped, isTrue);
      expect(received, alarmSkip());
    });

    testWidgets('Atlanmis satirda anahtari acmak geri alir', (tester) async {
      bool? skipped;

      await pumpCard(
        tester,
        alarm: (alarm: sahur, time: alarmAt),
        skips: {alarmSkip()},
        onSkipChanged: (_, value) => skipped = value,
      );

      await tester.tap(find.byType(Switch));

      expect(skipped, isFalse);
    });
  });
}
