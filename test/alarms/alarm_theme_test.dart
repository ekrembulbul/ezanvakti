import 'package:ezanvakti/core/models/alarm_theme.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/core/theme/palettes.dart';
import 'package:ezanvakti/features/alarms/domain/alarm_scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PrayerTime _day(DateTime date) {
  DateTime at(int hour, int minute) =>
      DateTime(date.year, date.month, date.day, hour, minute);

  return PrayerTime(
    date: DateTime(date.year, date.month, date.day),
    fajr: at(4, 3),
    sunrise: at(5, 43),
    dhuhr: at(13, 0),
    asr: at(16, 52),
    maghrib: at(20, 6),
    isha: at(21, 39),
  );
}

AlarmAppearance _appearance({
  Brightness brightness = Brightness.dark,
  bool timeBasedColor = true,
  DayPhase fixedPalette = DayPhase.evening,
}) {
  return AlarmAppearance(
    brightness: brightness,
    timeBasedColor: timeBasedColor,
    fixedPalette: fixedPalette,
  );
}

void main() {
  group('AlarmTheme', () {
    test('Palet renklerini RRGGBB olarak gonderir', () {
      final theme = AlarmTheme.forPalette(DayPhase.night, Brightness.dark);
      final map = theme.toMap();

      expect(map['accent'], '#CDA6E4');
      expect(map['backgroundStops'], ['#2A2038', '#17111F', '#0A080E']);
      expect(map['textPrimary'], '#F2ECF6');
      expect(map['textSecondary'], '#B3A5C1');
    });

    test('Vakte gore renk acikken calma anindaki dilim kullanilir', () {
      final theme = AlarmTheme.resolve(
        appearance: _appearance(fixedPalette: DayPhase.night),
        phaseAtFire: DayPhase.morning,
      );

      expect(
        theme.accent,
        paletteFor(DayPhase.morning, Brightness.dark).accent,
      );
    });

    test('Vakte gore renk kapaliyken kullanicinin sabit paleti kullanilir', () {
      final theme = AlarmTheme.resolve(
        appearance: _appearance(
          timeBasedColor: false,
          fixedPalette: DayPhase.night,
        ),
        phaseAtFire: DayPhase.morning,
      );

      expect(theme.accent, paletteFor(DayPhase.night, Brightness.dark).accent);
    });

    test('Acik tema secilmisse calar ekran da acik palette cizilir', () {
      final theme = AlarmTheme.resolve(
        appearance: _appearance(brightness: Brightness.light),
        phaseAtFire: DayPhase.morning,
      );
      final light = paletteFor(DayPhase.morning, Brightness.light);

      expect(theme.accent, light.accent);
      expect(theme.backgroundStops, light.backgroundStops);
      expect(theme.textPrimary, light.textPrimary);
    });

    test('Koyu ve acik ayni dilimde farkli renkler verir', () {
      final dark = AlarmTheme.resolve(
        appearance: _appearance(),
        phaseAtFire: DayPhase.evening,
      );
      final light = AlarmTheme.resolve(
        appearance: _appearance(brightness: Brightness.light),
        phaseAtFire: DayPhase.evening,
      );

      expect(dark.accent, isNot(light.accent));
    });

    test('Varsayilan gorunum: koyu tema, vakte gore renk', () {
      expect(AlarmAppearance.fallback.brightness, Brightness.dark);
      expect(AlarmAppearance.fallback.timeBasedColor, isTrue);
      expect(AlarmAppearance.fallback.fixedPalette, fallbackDayPhase);
    });
  });

  group('AlarmScheduler.themeForFire', () {
    final byDate = {DateTime(2026, 8, 4): _day(DateTime(2026, 8, 4))};

    test('Calma anindaki dilim paleti secilir, planlama anindaki degil', () {
      // 05:00 -> Imsak ile Ogle arasi: CIVIT (morning).
      final morning = AlarmScheduler.themeForFire(
        DateTime(2026, 8, 4, 5, 0),
        byDate,
        _appearance(),
      );
      // 22:00 -> Yatsi sonrasi: SUMBUL (night).
      final night = AlarmScheduler.themeForFire(
        DateTime(2026, 8, 4, 22, 0),
        byDate,
        _appearance(),
      );

      expect(
        morning.accent,
        paletteFor(DayPhase.morning, Brightness.dark).accent,
      );
      expect(night.accent, paletteFor(DayPhase.night, Brightness.dark).accent);
    });

    test('Sabit palet secilmisse calma ani dilimi yok sayilir', () {
      final theme = AlarmScheduler.themeForFire(
        DateTime(2026, 8, 4, 5, 0),
        byDate,
        _appearance(timeBasedColor: false, fixedPalette: DayPhase.evening),
      );

      expect(
        theme.accent,
        paletteFor(DayPhase.evening, Brightness.dark).accent,
      );
    });

    test('O gunun vakitleri yoksa fallback dilime duser', () {
      final theme = AlarmScheduler.themeForFire(
        DateTime(2026, 9, 20, 5, 0),
        byDate,
        _appearance(),
      );

      expect(
        theme.accent,
        paletteFor(fallbackDayPhase, Brightness.dark).accent,
      );
    });
  });
}
