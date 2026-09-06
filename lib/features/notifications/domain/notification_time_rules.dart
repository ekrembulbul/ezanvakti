import '../../../core/models/notification_setting.dart';
import '../../../core/models/prayer_time.dart';
import '../../prayer_times/domain/derived_times.dart';

/// Planlayıcı ve ekranlarda kullanılan ortak bildirim vakti kuralları.
class NotificationTimeRules {
  const NotificationTimeRules._();

  /// Aynı örnek için gün kısıtlı satırı genel satırdan önce değerlendirir.
  static List<NotificationSetting> prioritizeSettings(
    List<NotificationSetting> settings,
  ) => [
    ...settings.where((setting) => setting.isDayScoped),
    ...settings.where((setting) => !setting.isDayScoped),
  ];

  /// Sapma uygulanmamış vakit; veri eksikse veya tekrar günü uymuyorsa `null`.
  /// Gün filtresi, gece noktalarında kaynak gün yerine hesaplanan vakte bakar.
  static DateTime? pointTime({
    required NotificationSetting setting,
    required PrayerTime day,
    required Map<DateTime, PrayerTime> prayerTimesByDate,
  }) {
    final derived = setting.derivedKind;
    final point = derived == null
        ? switch (setting.prayerType) {
            PrayerType.fajr => day.fajr,
            PrayerType.sunrise => day.sunrise,
            PrayerType.dhuhr => day.dhuhr,
            PrayerType.asr => day.asr,
            PrayerType.maghrib => day.maghrib,
            PrayerType.isha => day.isha,
          }
        : DerivedTimes.resolve(
            kind: derived,
            day: day,
            nextDay:
                prayerTimesByDate[DateTime(
                  day.date.year,
                  day.date.month,
                  day.date.day + 1,
                )],
          );
    if (point == null || !setting.firesOnWeekday(point.weekday)) return null;
    return point;
  }
}
