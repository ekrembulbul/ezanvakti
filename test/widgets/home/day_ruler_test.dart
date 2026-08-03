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
  /// Serit takvim gununu kapsar: 00:00 solda, 24:00 sagda. Imsak->Yatsi
  /// aralik olarak alinsaydi gosterge Yatsi'dan gece yarisina kadar sag uca
  /// yapisip donuyordu.
  group('dayProgress', () {
    test('Gece yarisinda 0', () {
      expect(dayProgress(_times(), DateTime(2026, 8, 2, 0, 0)), 0.0);
    });

    test('Oglen 12:00 tam ortada', () {
      expect(
        dayProgress(_times(), DateTime(2026, 8, 2, 12, 0)),
        closeTo(0.5, 0.001),
      );
    });

    test('Imsak (04:00) gunun altida biri', () {
      expect(
        dayProgress(_times(), DateTime(2026, 8, 2, 4, 0)),
        closeTo(4 / 24, 0.001),
      );
    });

    test('Yatsi (22:00) sag ucta degil', () {
      final atIsha = dayProgress(_times(), DateTime(2026, 8, 2, 22, 0));

      expect(atIsha, closeTo(22 / 24, 0.001));
      expect(atIsha, lessThan(1.0), reason: 'Gece hala serit uzerinde');
    });

    test('Yatsi ile gece yarisi arasinda ilerlemeye devam eder', () {
      final atIsha = dayProgress(_times(), DateTime(2026, 8, 2, 22, 0));
      final later = dayProgress(_times(), DateTime(2026, 8, 2, 23, 30));

      expect(later, greaterThan(atIsha), reason: 'Gosterge donmamali');
      expect(later, lessThan(1.0));
    });

    test('Gun disi degerler kirpilir', () {
      expect(dayProgress(_times(), DateTime(2026, 8, 1, 23, 0)), 0.0);
      expect(dayProgress(_times(), DateTime(2026, 8, 3, 1, 0)), 1.0);
    });
  });

  group('DayRuler', () {
    testWidgets('Uclarda Imsak/Yatsi saati yazmaz', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(_ruler(DateTime(2026, 8, 2, 17, 34))),
      );

      // Ayni iki deger hemen altindaki vakit izgarasinda zaten var; seridin
      // uclarinda baglamsiz duruyorlardi.
      expect(find.text('04:00'), findsNothing);
      expect(find.text('22:00'), findsNothing);
    });

    testWidgets('Su anki saati gosterge etiketi olarak yazar', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(_ruler(DateTime(2026, 8, 2, 17, 34))),
      );

      expect(find.text('17:34'), findsOneWidget);
    });

    testWidgets('Yatak gece-gunduz-gece olarak bolunur, ustuste binmez', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(_ruler(DateTime(2026, 8, 2, 17, 34))),
      );

      final boxes = tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: find.byType(ClipRRect),
              matching: find.byType(ColoredBox),
            ),
          )
          .toList();

      expect(boxes, hasLength(3), reason: 'gece · gunduz · gece');

      final rects = find
          .descendant(
            of: find.byType(ClipRRect),
            matching: find.byType(ColoredBox),
          )
          .evaluate()
          .map((e) => tester.getRect(find.byWidget(e.widget)))
          .toList();

      // Parcalar seridi tam olarak doldurur; bindirme olsaydi toplam daha
      // buyuk cikardi ve gunduz bolgesi iki kat ton alirdi.
      final total = rects.fold<double>(0, (sum, r) => sum + r.width);
      expect(total, closeTo(360, 0.5));

      // Gunduz penceresi iki gece ucundan da belirgin sekilde koyu.
      final night = boxes.first.color.a;
      final day = boxes[1].color.a;
      expect(night / day, closeTo(0.45, 0.01));
      expect(boxes.last.color.a, closeTo(night, 0.001));
    });

    testWidgets('Alti vakit centigi cizilir', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(_ruler(DateTime(2026, 8, 2, 17, 34))),
      );

      expect(find.byKey(const Key('ruler_tick')), findsNWidgets(6));
    });

    testWidgets('Gecmis centikler vurgulu, gelecek olanlar sonuk', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(_ruler(DateTime(2026, 8, 2, 17, 34))),
      );

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
