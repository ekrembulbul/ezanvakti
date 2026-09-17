import 'package:ezanvakti/core/models/hijri_date.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:flutter_test/flutter_test.dart';

PrayerTime sample({HijriDate? hijri}) => PrayerTime(
  fajr: DateTime(2026, 9, 15, 5, 11),
  sunrise: DateTime(2026, 9, 15, 6, 37),
  dhuhr: DateTime(2026, 9, 15, 13, 4),
  asr: DateTime(2026, 9, 15, 16, 35),
  maghrib: DateTime(2026, 9, 15, 19, 22),
  isha: DateTime(2026, 9, 15, 20, 43),
  date: DateTime(2026, 9, 15),
  hijri: hijri,
);

void main() {
  test('hijri JSON gidis-donus (ic ice nesne)', () {
    final t = sample(hijri: const HijriDate(day: 4, month: 4, year: 1448));
    final json = t.toJson();
    expect(json['hijri'], {'day': 4, 'month': 4, 'year': 1448});
    expect(PrayerTime.fromJson(json), t);
  });

  test('hijri olmadan JSON null yazar ve okur', () {
    final t = sample();
    expect(t.toJson()['hijri'], isNull);
    expect(PrayerTime.fromJson(t.toJson()).hijri, isNull);
  });

  test('SQLite satirindaki duz sutunlardan hijri okunur', () {
    final row = sample().toJson()
      ..remove('hijri')
      ..addAll({'hijri_day': 4, 'hijri_month': 4, 'hijri_year': 1448});
    expect(
      PrayerTime.fromJson(row).hijri,
      const HijriDate(day: 4, month: 4, year: 1448),
    );
    final partial = sample().toJson()
      ..remove('hijri')
      ..addAll({'hijri_day': null, 'hijri_month': null, 'hijri_year': null});
    expect(PrayerTime.fromJson(partial).hijri, isNull);
  });

  test('copyWith hijri tasir ve esitlige girer', () {
    final a = sample();
    final b = a.copyWith(hijri: const HijriDate(day: 1, month: 1, year: 1448));
    expect(b.hijri, isNotNull);
    expect(a, isNot(b));
  });
}
