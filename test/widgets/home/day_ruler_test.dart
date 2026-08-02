import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/presentation/widgets/home/day_ruler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

/// Imsak 04:00, Gunes 06:00, Ogle 13:00, Ikindi 17:00, Aksam 20:00,
/// Yatsi 22:00 — toplam 18 saat.
PrayerTime _times() {
  DateTime at(int h, [int m = 0]) => DateTime(2026, 8, 2, h, m);
  return PrayerTime(
    fajr: at(4),
    sunrise: at(6),
    dhuhr: at(13),
    asr: at(17),
    maghrib: at(20),
    isha: at(22),
    date: DateTime(2026, 8, 2),
  );
}

Widget _ruler(DateTime now) => SizedBox(
  width: 360,
  child: DayRuler(prayerTime: _times(), now: now),
);

void main() {
  group('dayProgress', () {
    test('Imsak aninda 0', () {
      expect(dayProgress(_times(), DateTime(2026, 8, 2, 4, 0)), 0.0);
    });

    test('Yatsi aninda 1', () {
      expect(dayProgress(_times(), DateTime(2026, 8, 2, 22, 0)), 1.0);
    });

    test('Tam ortada 0.5', () {
      // 04:00 + 9 saat = 13:00
      expect(
        dayProgress(_times(), DateTime(2026, 8, 2, 13, 0)),
        closeTo(0.5, 0.001),
      );
    });

    test('Imsak oncesi 0 a kirpilir', () {
      expect(dayProgress(_times(), DateTime(2026, 8, 2, 2, 0)), 0.0);
    });

    test('Yatsi sonrasi 1 e kirpilir', () {
      expect(dayProgress(_times(), DateTime(2026, 8, 2, 23, 30)), 1.0);
    });
  });

  group('DayRuler', () {
    testWidgets('Uc saatleri gosterir', (tester) async {
      await tester.pumpWidget(wrapWithTheme(_ruler(DateTime(2026, 8, 2, 17, 34))));

      expect(find.text('04:00'), findsOneWidget);
      expect(find.text('22:00'), findsOneWidget);
    });

    testWidgets('Su anki saati gosterge etiketi olarak yazar', (tester) async {
      await tester.pumpWidget(wrapWithTheme(_ruler(DateTime(2026, 8, 2, 17, 34))));

      expect(find.text('17:34'), findsOneWidget);
    });

    testWidgets('Alti vakit centigi cizilir', (tester) async {
      await tester.pumpWidget(wrapWithTheme(_ruler(DateTime(2026, 8, 2, 17, 34))));

      expect(find.byKey(const Key('ruler_tick')), findsNWidgets(6));
    });

    testWidgets('Gecmis centikler vurgulu, gelecek olanlar sonuk', (
      tester,
    ) async {
      await tester.pumpWidget(wrapWithTheme(_ruler(DateTime(2026, 8, 2, 17, 34))));

      final tokens = tokensFor();
      final ticks = tester
          .widgetList<Container>(find.byKey(const Key('ruler_tick')))
          .map((c) => (c.decoration! as BoxDecoration).color)
          .toList();

      // Imsak/Gunes/Ogle/Ikindi gecti, Aksam/Yatsi gelecek.
      expect(ticks.take(4), everyElement(isNot(tokens.mutedTrack)));
      expect(ticks.skip(4), everyElement(tokens.mutedTrack));
    });
  });
}
