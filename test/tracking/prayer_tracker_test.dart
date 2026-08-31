import 'package:ezanvakti/core/models/notification_setting.dart' show PrayerType;
import 'package:ezanvakti/core/models/prayer_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrayerStatus', () {
    test('depolama degerleri kararli', () {
      for (final status in PrayerStatus.values) {
        expect(PrayerStatusX.fromStorage(status.storageValue), status);
      }
      expect(PrayerStatusX.fromStorage(null), isNull);
      expect(PrayerStatusX.fromStorage('bilinmeyen'), isNull);
    });

    test('dokunus dongusu: bos -> kildim -> kaza -> bos', () {
      expect(nextPrayerStatus(null), PrayerStatus.done);
      expect(nextPrayerStatus(PrayerStatus.done), PrayerStatus.qada);
      expect(nextPrayerStatus(PrayerStatus.qada), isNull);
    });

    test('kacirilmis kayit dongude kildima gecer', () {
      expect(nextPrayerStatus(PrayerStatus.missed), PrayerStatus.done);
    });
  });

  group('prayerLogKey', () {
    test('tarih ve vakitten kararli anahtar uretir', () {
      final key = prayerLogKey(DateTime(2026, 9, 4, 13, 30), PrayerType.dhuhr);
      expect(key, '2026-09-04|dhuhr');
    });

    test('gun ici saat anahtari degistirmez', () {
      expect(
        prayerLogKey(DateTime(2026, 9, 4), PrayerType.fajr),
        prayerLogKey(DateTime(2026, 9, 4, 23, 59), PrayerType.fajr),
      );
    });

    test('tek haneli ay ve gun sifirla doldurulur', () {
      expect(
        prayerLogKey(DateTime(2026, 1, 5), PrayerType.isha),
        '2026-01-05|isha',
      );
    });
  });

  group('kaza sayaci', () {
    test('negatife dusmez', () {
      expect(clampQadaCount(-3), 0);
      expect(clampQadaCount(0), 0);
      expect(clampQadaCount(7), 7);
    });

    test('makul ust sinirla kirpilir', () {
      expect(clampQadaCount(kMaxQadaCount + 100), kMaxQadaCount);
    });
  });

  test('takip edilen vakitler gunesi icermez', () {
    expect(trackedPrayerTypes, isNot(contains(PrayerType.sunrise)));
    expect(trackedPrayerTypes, hasLength(5));
  });
}
