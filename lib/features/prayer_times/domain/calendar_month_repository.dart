import '../../../core/models/location.dart';
import '../../../core/models/prayer_time.dart';
import 'prayer_times_repository.dart';

/// Vakit Takvimi'nin bir ayını yükler. [month] ayın herhangi bir günü
/// olabilir.
typedef CalendarMonthLoader =
    Future<List<PrayerTime>> Function({
      required Location location,
      required DateTime month,
      bool forceRefresh,
    });

/// Takvimin ay ay okuması. Ayrı hesap yapmaz: önbellek, gerektiğinde yıllık
/// indirme ve kullanıcı düzeltmesi uygulamanın geri kalanıyla aynı kapıdan
/// geçer (ADR 0004). Bildirim/alarm penceresine dokunmaz; yalnız okur.
class CalendarMonthRepository {
  final PrayerTimesRepository _prayerTimes;
  CalendarMonthRepository(this._prayerTimes);

  /// Ayın 1'i ile son günü istenir. Sunucu o yılı henüz yayımlamamışsa
  /// (404) sağlayıcı boş liste döner; bu hata değil, "yayımlanmadı" durumudur.
  Future<List<PrayerTime>> load({
    required Location location,
    required DateTime month,
    bool forceRefresh = false,
  }) async {
    final times = await _prayerTimes.getPrayerTimes(
      location: location,
      startDate: DateTime(month.year, month.month, 1),
      endDate: DateTime(month.year, month.month + 1, 0),
      forceRefresh: forceRefresh,
    );
    return _normalized(times);
  }

  /// Tarihe göre sıralar, aynı günün tekrarını eler. Önce eleme yapılır
  /// (ilk gelen kalır): `List.sort` kararlı değil, önce sıralamak hangi
  /// kopyanın kalacağını belirsiz bırakırdı.
  static List<PrayerTime> _normalized(List<PrayerTime> times) {
    final byDay = <DateTime, PrayerTime>{};
    for (final time in times) {
      byDay.putIfAbsent(
        DateTime(time.date.year, time.date.month, time.date.day),
        () => time,
      );
    }
    final days = byDay.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return List.unmodifiable(days);
  }
}
