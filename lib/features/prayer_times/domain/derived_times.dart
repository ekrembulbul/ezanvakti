import '../../../core/models/derived_time.dart';
import '../../../core/models/prayer_time.dart';

/// Türetilmiş vakitleri hesaplar. Saf: yalnızca gün verisi ve sabitlerle
/// çalışır, ağ ya da depo kullanmaz.
///
/// Gece vakitleri (gece yarısı, son üçte bir) **ertesi günün imsakını**
/// gerektirir: gece akşamla ertesi imsak arasıdır. Ertesi gün elde yoksa
/// `null` döner — planlayıcı o günü sessizce atlar.
class DerivedTimes {
  const DerivedTimes._();

  static DateTime? resolve({
    required DerivedTimeKind kind,
    required PrayerTime day,
    PrayerTime? nextDay,
    DerivedTimeSettings settings = DerivedTimeSettings.defaults,
  }) {
    switch (kind) {
      case DerivedTimeKind.ishraq:
        return day.sunrise.add(Duration(minutes: settings.ishraqMinutes));
      case DerivedTimeKind.istiwa:
        return day.dhuhr.subtract(Duration(minutes: settings.istiwaMinutes));
      case DerivedTimeKind.preMaghrib:
        return day.maghrib.subtract(
          Duration(minutes: settings.preMaghribMinutes),
        );
      case DerivedTimeKind.midnight:
        final night = _night(day, nextDay);
        return night == null ? null : day.maghrib.add(night ~/ 2);
      case DerivedTimeKind.lastThird:
        final night = _night(day, nextDay);
        return night == null ? null : nextDay!.fajr.subtract(night ~/ 3);
    }
  }

  /// Şer'i gece: akşamdan ertesi imsaka. Tutarsız veride (negatif ya da sıfır)
  /// hesap yapılmaz — bozuk bir gün gece yarısını sabaha kaydırmasın.
  static Duration? _night(PrayerTime day, PrayerTime? nextDay) {
    if (nextDay == null) return null;
    final night = nextDay.fajr.difference(day.maghrib);
    return night.inMinutes <= 0 ? null : night;
  }
}
