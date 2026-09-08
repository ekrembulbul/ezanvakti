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

  /// Alarmlar her çağrıda uzlaştırılır. Konum veya vakit verisi yoksa bildirim
  /// planlaması atlanır ve false döner; sabit alarmlar yine planlanır, mevcut
  /// çıpalı alarm kayıtları alarm planlayıcısının koruma listesinde kalır.
  ///
  /// İki planlama bağımsız tamamlanır; hatalar ayrı ayrı loglanır ve ilk hata
  /// ancak ikisi de tamamlandıktan sonra çağırana iletilir.
  Future<bool> reschedule({
    required Location? location,
    required List<PrayerTime> prayerTimes,
    required Set<SkippedOccurrence> skips,
  }) async {
    final canScheduleNotifications = location != null && prayerTimes.isNotEmpty;

    await Future.wait<void>([
      if (location != null && prayerTimes.isNotEmpty)
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
    return canScheduleNotifications;
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
