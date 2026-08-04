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

void main() {
  group('AlarmTheme', () {
    test('Palet renklerini RRGGBB olarak gonderir', () {
      final theme = AlarmTheme.forPhase(DayPhase.night);
      final map = theme.toMap();

      expect(map['accent'], '#CDA6E4');
      expect(map['backgroundStops'], ['#2A2038', '#17111F', '#0A080E']);
      expect(map['textPrimary'], '#F2ECF6');
      expect(map['textSecondary'], '#B3A5C1');
    });

    test('Her zaman koyu palet kullanir', () {
      for (final phase in DayPhase.values) {
        final theme = AlarmTheme.forPhase(phase);

        expect(
          theme.accent,
          paletteFor(phase, Brightness.dark).accent,
          reason: phase.name,
        );
      }
    });

    test('Fallback palet ERGUVAN', () {
      expect(
        AlarmTheme.fallback().accent,
        AlarmTheme.forPhase(fallbackDayPhase).accent,
      );
    });
  });

  group('AlarmScheduler.themeForFire', () {
    final date = DateTime(2026, 8, 4);
    final byDate = {DateTime(2026, 8, 4): _day(date)};

    test('Calma anindaki dilim paleti secilir, planlama anindaki degil', () {
      // 05:00 -> Imsak ile Ogle arasi: CIVIT (morning).
      final morning = AlarmScheduler.themeForFire(
        DateTime(2026, 8, 4, 5, 0),
        byDate,
      );
      // 22:00 -> Yatsi sonrasi: SUMBUL (night).
      final night = AlarmScheduler.themeForFire(
        DateTime(2026, 8, 4, 22, 0),
        byDate,
      );

      expect(
        morning.accent,
        paletteFor(DayPhase.morning, Brightness.dark).accent,
      );
      expect(night.accent, paletteFor(DayPhase.night, Brightness.dark).accent);
    });

    test('O gunun vakitleri yoksa fallback palete duser', () {
      final theme = AlarmScheduler.themeForFire(
        DateTime(2026, 9, 20, 5, 0),
        byDate,
      );

      expect(theme.accent, AlarmTheme.fallback().accent);
    });
  });
}
