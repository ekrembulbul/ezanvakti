import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/presentation/widgets/home/tomorrow_strip.dart';
import 'package:ezanvakti/presentation/widgets/home/upcoming_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../theme_harness.dart';

PrayerTime _tomorrow() {
  DateTime at(int h, int m) => DateTime(2026, 8, 3, h, m);
  return PrayerTime(
    fajr: at(4, 9),
    sunrise: at(5, 54),
    dhuhr: at(13, 15),
    asr: at(17, 10),
    maghrib: at(20, 26),
    isha: at(22, 2),
    date: DateTime(2026, 8, 3),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  group('TomorrowStrip', () {
    testWidgets('YARIN etiketi ve alti vakit gosterilir', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(
            width: 360,
            child: TomorrowStrip(tomorrow: _tomorrow(), onCalendarTap: () {}),
          ),
        ),
      );

      expect(find.text('YARIN'), findsOneWidget);
      expect(find.text('04:09'), findsOneWidget);
      expect(find.text('22:02'), findsOneWidget);
    });

    testWidgets('Gun adi ve hicri tarih yazilir', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(
            width: 360,
            child: TomorrowStrip(tomorrow: _tomorrow(), onCalendarTap: () {}),
          ),
        ),
      );

      expect(find.textContaining('Pazartesi'), findsOneWidget);
    });

    testWidgets('Takvim kisayoluna dokunmak callback cagirir', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(
            width: 360,
            child: TomorrowStrip(
              tomorrow: _tomorrow(),
              onCalendarTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Takvim'));
      expect(tapped, isTrue);
    });
  });

  group('UpcomingCard', () {
    testWidgets('SIRADAKI etiketi ve bos durum metni', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(SizedBox(width: 360, child: UpcomingCard(onSeeAll: () {}))),
      );

      expect(find.text('SIRADAKİ'), findsOneWidget);
      expect(find.text('Yaklaşan bildirim veya alarm yok'), findsOneWidget);
    });

    testWidgets('Tumu kisayoluna dokunmak callback cagirir', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(
            width: 360,
            child: UpcomingCard(onSeeAll: () => tapped = true),
          ),
        ),
      );

      await tester.tap(find.text('Tümü'));
      expect(tapped, isTrue);
    });
  });
}
