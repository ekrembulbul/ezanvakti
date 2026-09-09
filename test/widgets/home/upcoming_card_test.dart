import 'package:ezanvakti/presentation/widgets/home/upcoming_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/mission_session.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/skipped_occurrence.dart';
import 'package:ezanvakti/features/notifications/domain/notification_scheduler.dart';
import 'package:ezanvakti/presentation/services/upcoming_resolver.dart';

import '../theme_harness.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
    await initializeDateFormatting('ar', null);
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
      double width = 360,
      double textScale = 1,
      Locale locale = const Locale('tr'),
      List<MissionSession> missionSessions = const [],
    }) async {
      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: SizedBox(
                width: width,
                child: UpcomingCard(
                  now: now,
                  notification: notification,
                  alarm: alarm,
                  skips: skips,
                  missionSessions: missionSessions,
                  onSkipChanged: onSkipChanged,
                  onSeeAll: onSeeAll ?? () {},
                ),
              ),
            ),
          ),
          locale: locale,
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
      expect(find.text('Akşam · 10 dk önce'), findsOneWidget);
      expect(find.text('bugün 20:15 · 2 sa 33 dk'), findsOneWidget);
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

      expect(find.text('Yatsı · Tam vaktinde'), findsOneWidget);
      expect(find.text('bugün 22:01 · 4 sa 19 dk'), findsOneWidget);
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
          width: 320,
          textScale: 1.8,
        );
        expect(find.text('Cuma namazı'), findsOneWidget);
        expect(find.text('Öğle · 45 dk önce'), findsOneWidget);
        expect(find.text('Cuma 12:17 · 3 gün 18 sa 35 dk'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Arapça özel etiket dar ekranda ayrı ve görünür kalır', (
      tester,
    ) async {
      await pumpCard(
        tester,
        notification: (
          setting: const NotificationSetting(
            prayerType: PrayerType.dhuhr,
            isActive: true,
            minutesBefore: 45,
            label: 'صلاة الجمعة',
          ),
          prayerDate: DateTime(2026, 8, 7),
          time: DateTime(2026, 8, 7, 12, 17),
        ),
        width: 320,
        textScale: 1.8,
        locale: const Locale('ar'),
      );

      expect(find.text('صلاة الجمعة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Alarm satiri etiket, cipa ve gun yazar', (tester) async {
      await pumpCard(tester, alarm: (alarm: sahur, time: alarmAt));

      expect(find.text('İmsak · 30 dk önce'), findsOneWidget);
      expect(find.text('yarın 03:41 · 9 sa 59 dk'), findsOneWidget);
      expect(find.text('Sahur'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('Görevli alarm ana zamanın yanında görev ikonunu gösterir', (
      tester,
    ) async {
      await pumpCard(
        tester,
        alarm: (alarm: sahur.copyWith(mission: AlarmMission.qr), time: alarmAt),
      );

      expect(find.text('İmsak · 30 dk önce'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
    });

    testWidgets('Ertelenmis gorevli alarmin atlama anahtari kilitli degil', (
      tester,
    ) async {
      // Kilitli anahtar kullaniciyi cikissiz birakiyordu; artik dokunus gorev
      // kapisina gidiyor, karar orada veriliyor.
      SkippedOccurrence? changed;
      await pumpCard(
        tester,
        alarm: (alarm: sahur.copyWith(mission: AlarmMission.qr), time: alarmAt),
        missionSessions: [
          MissionSession(
            alarmId: sahur.id,
            firedAt: now,
            snoozedUntil: now.add(const Duration(minutes: 8)),
          ),
        ],
        onSkipChanged: (occurrence, _) => changed = occurrence,
      );

      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(changed?.reference, sahur.id);
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
      expect(find.text('bugün · 2 sa'), findsOneWidget);
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
      expect(find.text('Akşam · 10 dk önce'), findsOneWidget);
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

      expect(find.text('İmsak · 30 dk önce'), findsOneWidget);
      expect(
        find.text('Yalnızca bu sefer atlanacak · yarın 03:41'),
        findsOneWidget,
      );
      expect(find.text('Sahur'), findsOneWidget);
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
