import '../../../core/models/notification_setting.dart' show PrayerType;
import '../../../core/models/prayer_time.dart';

/// Kullanıcının vakit başına verdiği ± dakika düzeltmesini uygular.
///
/// Düzeltme **yerelde** uygulanır, Aladhan'ın `tune` parametresiyle değil:
/// önbellek ham veriyi tutar ve düzeltme okurken uygulanır. Böylece ayar
/// değişince yeniden fetch gerekmez, çevrimdışı da çalışır ve önbellek
/// geçersizleştirme derdi olmaz.
class PrayerTimeTuner {
  const PrayerTimeTuner._();

  /// Boş/etkisiz düzeltmede liste olduğu gibi döner (gereksiz kopya yok).
  static List<PrayerTime> apply(
    List<PrayerTime> times,
    Map<PrayerType, int> tune,
  ) {
    if (_isEmpty(tune) || times.isEmpty) return times;
    return [for (final time in times) applyOne(time, tune)];
  }

  static PrayerTime applyOne(PrayerTime time, Map<PrayerType, int> tune) {
    if (_isEmpty(tune)) return time;
    return PrayerTime(
      date: time.date,
      fajr: _shift(time.fajr, tune[PrayerType.fajr]),
      sunrise: _shift(time.sunrise, tune[PrayerType.sunrise]),
      dhuhr: _shift(time.dhuhr, tune[PrayerType.dhuhr]),
      asr: _shift(time.asr, tune[PrayerType.asr]),
      maghrib: _shift(time.maghrib, tune[PrayerType.maghrib]),
      isha: _shift(time.isha, tune[PrayerType.isha]),
    );
  }

  static bool _isEmpty(Map<PrayerType, int> tune) =>
      tune.isEmpty || tune.values.every((minutes) => minutes == 0);

  static DateTime _shift(DateTime time, int? minutes) =>
      (minutes == null || minutes == 0)
      ? time
      : time.add(Duration(minutes: minutes));
}
