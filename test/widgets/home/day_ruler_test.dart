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

  /// Vakitler seridin uzerine cizilmez; parcalar arasinda gercek bosluk
  /// birakilir. Zemin rengi tahmin edilmeye calisildiginda, seridin
  /// bulundugu noktadaki gradyan tonuna denk gelmiyor ve isaret yerine acik
  /// leke uretiyordu.
  /// Gunduz penceresi Imsak -> Aksam (gun batimi); Yatsi gunduzun sonu degil,
  /// gecenin icindeki bir sinir.
  group('buildRulerSegments', () {
    // Imsak 4/24, Gunes 6/24, Ogle 13/24, Ikindi 17/24, Aksam 20/24,
    // Yatsi 22/24.
    const fractions = [4 / 24, 6 / 24, 13 / 24, 17 / 24, 20 / 24, 22 / 24];

    test('Gun basi ve sonu gece olarak isaretlenir', () {
      final segments = buildRulerSegments(
        prayerFractions: fractions,
        dayStart: fractions[0],
        dayEnd: fractions[4],
        progress: 17.5 / 24,
      );

      expect(segments.first.kind, RulerSegmentKind.night);
      expect(segments.first.start, 0);
      expect(segments.first.end, closeTo(4 / 24, 0.001));

      expect(segments.last.kind, RulerSegmentKind.night);
      expect(segments.last.end, 1);

      // Aksam'dan (20/24) sonrasi gece; Yatsi bu geceyi ikiye boler ama
      // ikisi de gece.
      final afterMaghrib = segments.where((s) => s.start >= 20 / 24);
      expect(afterMaghrib, hasLength(2));
      expect(
        afterMaghrib,
        everyElement(
          isA<RulerSegment>().having(
            (s) => s.kind,
            'kind',
            RulerSegmentKind.night,
          ),
        ),
      );
    });

    test('Yatsi gunduz penceresine dahil degil', () {
      // 21:00 -> Aksam gecti, Yatsi gecmedi. Bu an gece bolgesinde.
      final segments = buildRulerSegments(
        prayerFractions: fractions,
        dayStart: fractions[0],
        dayEnd: fractions[4],
        progress: 21 / 24,
      );

      final atNow = segments.firstWhere(
        (s) => s.start <= 21 / 24 && s.end >= 21 / 24,
      );
      expect(atNow.kind, RulerSegmentKind.night);
    });

    test('Gece, gecmis olsa bile vurgulanmaz', () {
      // Gece yarisi coktan gecti ama sol uc yine de sonuk kalmali: gece
      // namaz gununun parcasi degil.
      final segments = buildRulerSegments(
        prayerFractions: fractions,
        dayStart: fractions[0],
        dayEnd: fractions[4],
        progress: 23 / 24,
      );

      expect(segments.first.kind, RulerSegmentKind.night);
      expect(segments.last.kind, RulerSegmentKind.night);
    });

    test('Icinde bulunulan aralik ikiye bolunur', () {
      final segments = buildRulerSegments(
        prayerFractions: fractions,
        dayStart: fractions[0],
        dayEnd: fractions[4],
        progress: 18 / 24,
      );

      // Ikindi (17) - Aksam (20) araligi 18'de bolunur.
      final split = segments.where(
        (s) => s.start == 18 / 24 || s.end == 18 / 24,
      );
      expect(split, hasLength(2));
      expect(
        segments.firstWhere((s) => s.end == 18 / 24).kind,
        RulerSegmentKind.elapsed,
      );
      expect(
        segments.firstWhere((s) => s.start == 18 / 24).kind,
        RulerSegmentKind.upcoming,
      );
    });

    test('Parcalar bosluksuz ve artan sirada gunu kapsar', () {
      final segments = buildRulerSegments(
        prayerFractions: fractions,
        dayStart: fractions[0],
        dayEnd: fractions[4],
        progress: 12 / 24,
      );

      expect(segments.first.start, 0);
      expect(segments.last.end, 1);
      for (var i = 1; i < segments.length; i++) {
        expect(segments[i].start, closeTo(segments[i - 1].end, 0.0001));
      }
    });

    test('Aksam gectikten sonra gunduz penceresi tamamen gecmis', () {
      final segments = buildRulerSegments(
        prayerFractions: fractions,
        dayStart: fractions[0],
        dayEnd: fractions[4],
        progress: 22.5 / 24,
      );

      final day = segments.where((s) => s.kind != RulerSegmentKind.night);
      expect(
        day,
        everyElement(
          isA<RulerSegment>().having(
            (s) => s.kind,
            'kind',
            RulerSegmentKind.elapsed,
          ),
        ),
      );
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

    testWidgets('Saat etiketi noktanin altinda kalmaz', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(_ruler(DateTime(2026, 8, 2, 17, 34))),
      );

      final label = tester.getRect(find.text('17:34'));
      // Nokta: yatagin merkezine hizali 16px daire. Etiketin alt kenari
      // noktanin ust kenarindan yukarida olmali.
      final dot = tester.getRect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      );

      expect(label.bottom, lessThanOrEqualTo(dot.top));
    });

    testWidgets('Alti vakit centigi cizilir', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(_ruler(DateTime(2026, 8, 2, 17, 34))),
      );

      expect(find.byKey(const Key('ruler_tick')), findsNWidgets(6));
    });

    testWidgets('Alti centik de ayni: 2x7 ve ayni renk', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(_ruler(DateTime(2026, 8, 2, 17, 34))),
      );

      final sizes = find
          .byKey(const Key('ruler_tick'))
          .evaluate()
          .map((e) => tester.getSize(find.byWidget(e.widget)))
          .toSet();
      final colors = tester
          .widgetList<Container>(find.byKey(const Key('ruler_tick')))
          .map((c) => (c.decoration! as BoxDecoration).color)
          .toSet();

      // Icinde bulunulan vakti ayrica isaretlemeye gerek yok: seridin kendi
      // renk gecisi ve alttaki izgara bunu zaten soyluyor.
      expect(sizes, hasLength(1));
      expect(sizes.single, const Size(2, 7));
      expect(colors, hasLength(1));
      expect(colors.single, tokensFor().textTertiary.withValues(alpha: 0.7));
    });

    testWidgets('Ilerleme dolgusu ayri bir katman degil', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(_ruler(DateTime(2026, 8, 2, 22, 18))),
      );

      // Serit tek bir CustomPaint; ustune binen dolgu/centik katmani yok.
      // Once dolu accent cubugu gece ucunu ve centikleri ortuyordu.
      final gradients = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.decoration is BoxDecoration)
          .map((c) => c.decoration! as BoxDecoration)
          .where((d) => d.gradient != null);

      expect(gradients, isEmpty);
    });
  });
}
