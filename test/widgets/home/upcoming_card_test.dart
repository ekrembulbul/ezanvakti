import 'package:ezanvakti/presentation/widgets/home/upcoming_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/presentation/services/upcoming_resolver.dart';

import '../theme_harness.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  group('UpcomingCard', () {
    final now = DateTime(2026, 8, 3, 17, 42);

    Future<void> pumpCard(
      WidgetTester tester, {
      UpcomingNotification? notification,
      UpcomingAlarm? alarm,
      VoidCallback? onSeeAll,
      void Function(Alarm, bool)? onAlarmToggled,
    }) async {
      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(
            width: 360,
            child: UpcomingCard(
              now: now,
              notification: notification,
              alarm: alarm,
              onAlarmToggled: onAlarmToggled,
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

    testWidgets('Bildirim satiri vakit, sapma ve kalan sureyi yazar', (
      tester,
    ) async {
      await pumpCard(
        tester,
        notification: (
          setting: const NotificationSetting(
            prayerType: PrayerType.maghrib,
            isActive: true,
            minutesBefore: 10,
          ),
          time: DateTime(2026, 8, 3, 20, 25),
        ),
      );

      expect(find.text('Akşam bildirimi'), findsOneWidget);
      expect(find.text('10 dk önce · 20:25'), findsOneWidget);
      expect(find.text('2s 43dk'), findsOneWidget);
    });

    testWidgets('Tam vaktinde bildirim sapma yazmaz', (tester) async {
      await pumpCard(
        tester,
        notification: (
          setting: const NotificationSetting(
            prayerType: PrayerType.isha,
            isActive: true,
          ),
          time: DateTime(2026, 8, 3, 22, 1),
        ),
      );

      expect(find.text('Tam vaktinde · 22:01'), findsOneWidget);
    });

    testWidgets('Alarm satiri etiket, cipa ve gun yazar', (tester) async {
      await pumpCard(
        tester,
        alarm: (
          alarm: const Alarm(
            id: 'a',
            kind: AlarmKind.anchored,
            label: 'Sahur',
            anchor: PrayerType.fajr,
            offsetMinutes: -30,
          ),
          time: DateTime(2026, 8, 4, 3, 41),
        ),
      );

      expect(find.text('Sahur'), findsOneWidget);
      expect(find.text('İmsak −30 dk · yarın 03:41'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('Alarm anahtari callback tetikler', (tester) async {
      bool? toggled;

      await pumpCard(
        tester,
        alarm: (
          alarm: const Alarm(
            id: 'a',
            kind: AlarmKind.fixed,
            hour: 6,
            minute: 30,
          ),
          time: DateTime(2026, 8, 4, 6, 30),
        ),
        onAlarmToggled: (_, value) => toggled = value,
      );

      await tester.tap(find.byType(Switch));
      expect(toggled, isFalse);
    });
  });
}
