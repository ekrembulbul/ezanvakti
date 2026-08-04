import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026 Agustos'unun [day] gunu icin sabit vakitli bir gun uretir.
/// Imsak 04:00, Ogle 13:00, Ikindi 17:00, Aksam 20:00, Yatsi 22:00.
PrayerTime _day(int day) {
  DateTime at(int hour) => DateTime(2026, 8, day, hour, 0);
  return PrayerTime(
    fajr: at(4),
    sunrise: at(6),
    dhuhr: at(13),
    asr: at(17),
    maghrib: at(20),
    isha: at(22),
    date: DateTime(2026, 8, day),
  );
}

void main() {
  final today = _day(1);
  final tomorrow = _day(2);

  group('resolveDayPhase', () {
    test('Imsak ile Ogle arasi morning', () {
      expect(
        resolveDayPhase(
          today: today,
          tomorrow: tomorrow,
          now: DateTime(2026, 8, 1, 9, 0),
        ),
        DayPhase.morning,
      );
    });

    test('Ogle ile Ikindi arasi afternoon', () {
      expect(
        resolveDayPhase(
          today: today,
          tomorrow: tomorrow,
          now: DateTime(2026, 8, 1, 15, 0),
        ),
        DayPhase.afternoon,
      );
    });

    test('Ikindi ile Yatsi arasi evening — sinir Aksam degil Yatsi', () {
      // Aksam 20:00'de; tasarim geregi palet burada degismez, 21:00'de hala
      // evening olmali.
      expect(
        resolveDayPhase(
          today: today,
          tomorrow: tomorrow,
          now: DateTime(2026, 8, 1, 21, 0),
        ),
        DayPhase.evening,
      );
    });

    test('Yatsi sonrasi night', () {
      expect(
        resolveDayPhase(
          today: today,
          tomorrow: tomorrow,
          now: DateTime(2026, 8, 1, 23, 0),
        ),
        DayPhase.night,
      );
    });

    test('Gece yarisindan sonra, Imsak oncesi hala night', () {
      expect(
        resolveDayPhase(
          today: _day(2),
          tomorrow: _day(3),
          now: DateTime(2026, 8, 2, 2, 0),
        ),
        DayPhase.night,
      );
    });

    test('Vakit verisi yoksa evening dondurur', () {
      expect(
        resolveDayPhase(
          today: null,
          tomorrow: null,
          now: DateTime(2026, 8, 1, 9, 0),
        ),
        DayPhase.evening,
      );
    });

    test(
      'Sinir anlari bir sonraki dilime ait: tam Ogle vaktinde afternoon',
      () {
        expect(
          resolveDayPhase(
            today: today,
            tomorrow: tomorrow,
            now: DateTime(2026, 8, 1, 13, 0),
          ),
          DayPhase.afternoon,
        );
      },
    );

    test('Tam Imsak vaktinde morning', () {
      expect(
        resolveDayPhase(
          today: today,
          tomorrow: tomorrow,
          now: DateTime(2026, 8, 1, 4, 0),
        ),
        DayPhase.morning,
      );
    });

    test('Tam Yatsi vaktinde night', () {
      expect(
        resolveDayPhase(
          today: today,
          tomorrow: tomorrow,
          now: DateTime(2026, 8, 1, 22, 0),
        ),
        DayPhase.night,
      );
    });
  });

  group('nextDayPhaseBoundary', () {
    test('morning icindeyken sonraki sinir Ogle', () {
      expect(
        nextDayPhaseBoundary(
          today: today,
          tomorrow: tomorrow,
          now: DateTime(2026, 8, 1, 9, 0),
        ),
        DateTime(2026, 8, 1, 13, 0),
      );
    });

    test('evening icindeyken sonraki sinir Yatsi', () {
      expect(
        nextDayPhaseBoundary(
          today: today,
          tomorrow: tomorrow,
          now: DateTime(2026, 8, 1, 18, 0),
        ),
        DateTime(2026, 8, 1, 22, 0),
      );
    });

    test('Yatsi sonrasi sonraki sinir ertesi gunun Imsak i', () {
      expect(
        nextDayPhaseBoundary(
          today: today,
          tomorrow: tomorrow,
          now: DateTime(2026, 8, 1, 23, 0),
        ),
        DateTime(2026, 8, 2, 4, 0),
      );
    });

    test('Yarin verisi yoksa bugunun Imsak ina 24 saat eklenir', () {
      expect(
        nextDayPhaseBoundary(
          today: today,
          tomorrow: null,
          now: DateTime(2026, 8, 1, 23, 0),
        ),
        DateTime(2026, 8, 2, 4, 0),
      );
    });

    test('Gece yarisi sonrasi sonraki sinir bugunun Imsak i', () {
      expect(
        nextDayPhaseBoundary(
          today: _day(2),
          tomorrow: _day(3),
          now: DateTime(2026, 8, 2, 2, 0),
        ),
        DateTime(2026, 8, 2, 4, 0),
      );
    });

    test('Vakit verisi yoksa null', () {
      expect(
        nextDayPhaseBoundary(
          today: null,
          tomorrow: null,
          now: DateTime(2026, 8, 1, 9, 0),
        ),
        isNull,
      );
    });
  });
}
