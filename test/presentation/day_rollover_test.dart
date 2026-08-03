import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/presentation/services/day_rollover.dart';
import 'package:flutter_test/flutter_test.dart';

PrayerTime _day(DateTime date) {
  DateTime at(int h, int m) => DateTime(date.year, date.month, date.day, h, m);
  return PrayerTime(
    fajr: at(4, 1),
    sunrise: at(5, 42),
    dhuhr: at(13, 0),
    asr: at(16, 52),
    maghrib: at(20, 7),
    isha: at(21, 41),
    date: DateTime(date.year, date.month, date.day),
  );
}

/// Vakit tablosu miladi takvim gununune bagli; gun donumu bir vakitte degil
/// gece yarisinda olur. Tazeleme yapilmazsa 00:00 sonrasi ekran dunu
/// gostermeye devam ediyordu.
void main() {
  group('delayToNextMidnight', () {
    test('Gun ortasindan gece yarisina kalan sure', () {
      final delay = delayToNextMidnight(DateTime(2026, 8, 3, 12, 0));

      expect(delay, const Duration(hours: 12) + kMidnightMargin);
    });

    test('Gece yarisina cok yakinken kisa bekler', () {
      final delay = delayToNextMidnight(DateTime(2026, 8, 3, 23, 59, 30));

      expect(delay, const Duration(seconds: 30) + kMidnightMargin);
    });

    test('Gece yarisinin hemen ardinda bir sonraki gunu bekler', () {
      final delay = delayToNextMidnight(DateTime(2026, 8, 3, 0, 0, 1));

      expect(
        delay,
        const Duration(hours: 24) -
            const Duration(seconds: 1) +
            kMidnightMargin,
      );
    });

    test('Bekleme her zaman pozitif', () {
      for (var hour = 0; hour < 24; hour++) {
        final delay = delayToNextMidnight(DateTime(2026, 8, 3, hour, 30));

        expect(delay, greaterThan(Duration.zero), reason: 'saat $hour');
      }
    });
  });

  group('isPrayerDataStale', () {
    test('Ayni gunun verisi bayat degil', () {
      final now = DateTime(2026, 8, 3, 23, 59);

      expect(isPrayerDataStale(_day(now), now), isFalse);
    });

    test('Gece yarisini gecince dunun verisi bayat', () {
      // Kullanicinin bildirdigi durum: 00:13'te ekran hala dunu gosteriyordu.
      final loaded = _day(DateTime(2026, 8, 3));
      final now = DateTime(2026, 8, 4, 0, 13);

      expect(isPrayerDataStale(loaded, now), isTrue);
    });

    test('Veri yokken bayat sayilmaz', () {
      expect(isPrayerDataStale(null, DateTime(2026, 8, 4)), isFalse);
    });

    test('Ay ve yil donumu de yakalanir', () {
      expect(
        isPrayerDataStale(
          _day(DateTime(2026, 12, 31)),
          DateTime(2027, 1, 1, 0, 5),
        ),
        isTrue,
      );
    });
  });
}
