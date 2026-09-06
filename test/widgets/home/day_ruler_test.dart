import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/features/prayer_times/domain/kerahat_times.dart';
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

    test('Berlin DST gunlerinde gercek 23/25 saatlik gun oranini kullanir', () {
      final springDate = DateTime(2026, 3, 29);
      final springEnd = DateTime(2026, 3, 30);
      final autumnDate = DateTime(2026, 10, 25);
      final autumnEnd = DateTime(2026, 10, 26);
      if (springEnd.difference(springDate).inHours != 23 ||
          autumnEnd.difference(autumnDate).inHours != 25) {
        markTestSkipped('TZ=Europe/Berlin gerektirir');
        return;
      }

      expect(
        dayProgress(
          _times().copyWith(date: springDate),
          DateTime(2026, 3, 29, 12),
        ),
        closeTo(11 / 23, 0.0001),
      );
      expect(
        dayProgress(
          _times().copyWith(date: autumnDate),
          DateTime(2026, 10, 25, 12),
        ),
        closeTo(13 / 25, 0.0001),
      );
    });
  });

  /// Vakitler seridin uzerine cizilmez; parcalar arasinda gercek bosluk
  /// birakilir. Zemin rengi tahmin edilmeye calisildiginda, seridin
  /// bulundugu noktadaki gradyan tonuna denk gelmiyor ve isaret yerine acik
  /// leke uretiyordu.
  /// Gunduz penceresi Imsak -> Aksam (gun batimi); Yatsi gunduzun sonu degil,
  /// Gunduz penceresi Imsak -> Aksam (gun batimi); Yatsi gunduzun sonu degil,
  /// gecenin icindeki bir sinir. Gecmis/gelmemis ayrimi yok: nerede oldugumuzu
  /// gosterge noktasi soyluyor.
  group('buildRulerSegments', () {
    // Imsak 4/24, Gunes 6/24, Ogle 13/24, Ikindi 17/24, Aksam 20/24,
    // Yatsi 22/24.
    const fractions = [4 / 24, 6 / 24, 13 / 24, 17 / 24, 20 / 24, 22 / 24];

    List<RulerSegment> build() => buildRulerSegments(
      prayerFractions: fractions,
      dayStart: fractions[0],
      dayEnd: fractions[4],
    );

    test('Gun basi ve sonu gece', () {
      final segments = build();

      expect(segments.first.kind, RulerSegmentKind.night);
      expect(segments.first.start, 0);
      expect(segments.first.end, closeTo(4 / 24, 0.001));

      expect(segments.last.kind, RulerSegmentKind.night);
      expect(segments.last.end, 1);
    });

    test('Aksam sonrasi gece; Yatsi bu geceyi ikiye boler', () {
      final afterMaghrib = build().where((s) => s.start >= 20 / 24);

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

    test('Imsak ile Aksam arasi gunduz', () {
      final day = build().where((s) => s.start >= 4 / 24 && s.end <= 20 / 24);

      expect(day, hasLength(4));
      expect(
        day,
        everyElement(
          isA<RulerSegment>().having(
            (s) => s.kind,
            'kind',
            RulerSegmentKind.day,
          ),
        ),
      );
    });

    test('Parcalar bosluksuz ve artan sirada gunu kapsar', () {
      final segments = build();

      expect(segments.first.start, 0);
      expect(segments.last.end, 1);
      for (var i = 1; i < segments.length; i++) {
        expect(segments[i].start, closeTo(segments[i - 1].end, 0.0001));
      }
    });

    test('Alti vakit siniri yedi parca uretir', () {
      expect(build(), hasLength(7));
    });

    test(
      'Kerahat sinirlari orantili parcalar uretir ve vakit boslugu acmaz',
      () {
        final segments = buildRulerSegments(
          prayerFractions: fractions,
          dayStart: fractions[0],
          dayEnd: fractions[4],
          kerahatRanges: const [
            (start: 6 / 24, end: 6.75 / 24),
            (start: (13 * 60 - 10) / (24 * 60), end: 13 / 24),
            (start: 19.25 / 24, end: 20 / 24),
          ],
        );
        final kerahat = segments
            .where((segment) => segment.kind == RulerSegmentKind.kerahat)
            .toList();

        expect(kerahat, hasLength(3));
        expect(kerahat[0].gapAfter, isFalse);
        expect(kerahat[1].gapBefore, isFalse);
        expect(kerahat[1].gapAfter, isTrue);
      },
    );

    test('On dakikalik ogle parcasi 360 px cetvelde gorunur kalir', () {
      final segments = buildRulerSegments(
        prayerFractions: fractions,
        dayStart: fractions[0],
        dayEnd: fractions[4],
        kerahatRanges: const [
          (start: (13 * 60 - 10) / (24 * 60), end: 13 / 24),
        ],
      );
      final noon = segments.singleWhere(
        (segment) => segment.kind == RulerSegmentKind.kerahat,
      );

      expect(paintedRulerSegmentWidth(noon, 360), greaterThan(0.9));
    });
  });

  group('DayRuler', () {
    testWidgets(
      'Ogle kerahatinin namaz olmayan ic birlesimi piksel boslugu birakmaz',
      (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            SizedBox(
              width: 360,
              child: DayRuler(
                prayerTime: _times(),
                now: DateTime(2026, 8, 2, 12),
                kerahatIntervals: KerahatTimes.forDay(_times()),
              ),
            ),
          ),
        );

        const radius = Radius.circular(2.5);
        RRect segmentRRect(
          double left,
          double right, {
          required bool roundLeft,
          required bool roundRight,
        }) => RRect.fromLTRBAndCorners(
          left,
          0,
          right,
          5,
          topLeft: roundLeft ? radius : Radius.zero,
          bottomLeft: roundLeft ? radius : Radius.zero,
          topRight: roundRight ? radius : Radius.zero,
          bottomRight: roundRight ? radius : Radius.zero,
        );
        final tokens = tokensFor();

        expect(
          find.descendant(
            of: find.byType(DayRuler),
            matching: find.byType(CustomPaint),
          ),
          paints
            ..rrect(
              rrect: segmentRRect(0, 58.5, roundLeft: true, roundRight: true),
              color: tokens.textTertiary.withValues(alpha: 0.4),
            )
            ..rrect(
              rrect: segmentRRect(
                61.5,
                88.5,
                roundLeft: true,
                roundRight: true,
              ),
              color: tokens.accent,
            )
            ..rrect(
              rrect: segmentRRect(
                91.5,
                101.25,
                roundLeft: true,
                roundRight: false,
              ),
              color: tokens.kerahatLine,
            )
            ..rrect(
              rrect: segmentRRect(
                101.25,
                192.5,
                roundLeft: false,
                roundRight: false,
              ),
              color: tokens.accent,
            )
            ..rrect(
              rrect: segmentRRect(
                192.5,
                193.5,
                roundLeft: false,
                roundRight: true,
              ),
              color: tokens.kerahatLine,
            ),
        );
      },
    );

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

    testWidgets(
      'Kerahat araliklari RTL yonunde de ayni zaman eksenini kullanir',
      (tester) async {
        final intervals = KerahatTimes.forDay(_times());
        Future<List<double>> tickCenters(TextDirection direction) async {
          await tester.pumpWidget(
            wrapWithTheme(
              Directionality(
                textDirection: direction,
                child: SizedBox(
                  width: 360,
                  child: DayRuler(
                    prayerTime: _times(),
                    now: DateTime(2026, 8, 2, 12),
                    kerahatIntervals: intervals,
                  ),
                ),
              ),
            ),
          );
          return find
              .byKey(const Key('ruler_tick'))
              .evaluate()
              .map(
                (element) => tester.getCenter(find.byWidget(element.widget)).dx,
              )
              .toList();
        }

        final ltr = await tickCenters(TextDirection.ltr);
        final rtl = await tickCenters(TextDirection.rtl);

        expect(ltr, orderedEquals(rtl));
        expect(rtl, orderedEquals(rtl.toList()..sort()));
      },
    );
  });
}
