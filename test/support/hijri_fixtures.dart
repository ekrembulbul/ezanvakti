import 'package:ezanvakti/core/models/hijri_date.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';

/// Ardışık günlere ardışık Hicri tarih verir (30 günlük aylar, 12 ayda yıl devri).
/// Gerçek takvim 29/30 gün karışıktır; testler yalnız ay/gün eşleşmesine bakar.
List<PrayerTime> withSequentialHijri(List<PrayerTime> days, HijriDate first) {
  var day = first.day, month = first.month, year = first.year;
  final out = <PrayerTime>[];
  for (final d in days) {
    out.add(
      d.copyWith(
        hijri: HijriDate(day: day, month: month, year: year),
      ),
    );
    day++;
    if (day > 30) {
      day = 1;
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
  }
  return out;
}
