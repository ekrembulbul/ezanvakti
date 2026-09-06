import '../../core/models/location.dart';
import '../../core/models/prayer_time.dart';
import '../../core/models/skipped_occurrence.dart';
import '../../core/utils/app_logger.dart';
import '../../features/alarms/domain/alarm_scheduler.dart';
import '../../features/notifications/domain/notification_scheduler.dart';

/// Bildirim ve alarm planlamasının tek giriş noktası.
///
/// [reschedule] `skips`'i **zorunlu** parametre olarak ister. Geçirilmezse
/// kullanıcının "yalnızca bu sefer" atladığı örnek, ilgisiz bir değişiklikten
/// sonra sessizce geri planlanır ve çalar; bunu derleme zamanında imkânsız
/// kılmak için isteğe bağlı değil.
class ReminderRescheduler {
  final NotificationScheduler notificationScheduler;
  final AlarmScheduler alarmScheduler;

  const ReminderRescheduler({
    required this.notificationScheduler,
    required this.alarmScheduler,
  });

  /// Planlamayı yeniden kurar. Vakit verisi ya da konum yoksa `false` döner ve
  /// **hiçbir şeye dokunmaz** — geçici bir ağ hatası yüzünden kullanıcının
  /// mevcut bildirimlerini silmemek için. Silinen/kapatılan bir kaydın eski OS
  /// kopyasını iptal etmek çağıranın işidir.
  ///
  /// İki planlama bağımsız tamamlanır; hatalar ayrı ayrı loglanır ve ilk hata
  /// ancak ikisi de tamamlandıktan sonra çağırana iletilir.
  Future<bool> reschedule({
    required Location? location,
    required List<PrayerTime> prayerTimes,
    required Set<SkippedOccurrence> skips,
  }) async {
    if (location == null || prayerTimes.isEmpty) return false;

    await Future.wait<void>([
      _runSchedule(
        'notifications',
        () => notificationScheduler.scheduleNotifications(
          location: location,
          prayerTimes: prayerTimes,
          skips: skips,
        ),
      ),
      _runSchedule(
        'alarms',
        () => alarmScheduler.scheduleAlarms(
          prayerTimes: prayerTimes,
          skips: skips,
        ),
      ),
    ], eagerError: false);
    return true;
  }

  Future<void> _runSchedule(
    String kind,
    Future<void> Function() schedule,
  ) async {
    try {
      await schedule();
    } catch (error, stackTrace) {
      AppLogger().error(
        'Reminder scheduling failed (kind=$kind)',
        error,
        stackTrace,
      );
      rethrow;
    }
  }
}
