/// Sesli/kalıcı alarmların native teslim katmanı.
///
/// Bildirimlerden ayrıdır: alarm kapatılana kadar çalar, (platform destekliyorsa)
/// sessiz modu deler, ertelenebilir. Android'de AlarmManager + tam ekran intent,
/// iOS 26+'da AlarmKit ile gerçeklenir.
abstract class AlarmService {
  /// Bu platform/sürüm gerçek alarmı destekliyor mu?
  /// (Android: evet; iOS: yalnızca 26+.)
  Future<bool> isSupported();

  /// Alarm için gereken izinleri ister (Android: tam ekran/exact alarm; iOS:
  /// AlarmKit yetkilendirme). İzin verildiyse true döner.
  Future<bool> requestPermission();

  Future<bool> isPermissionGranted();

  /// Tek seferlik bir alarmı [scheduledTime] anında çalacak şekilde planlar.
  /// Aynı [id] ile tekrar çağrı, öncekini değiştirir.
  Future<void> scheduleAlarm({
    required String id,
    required DateTime scheduledTime,
    required String label,
    required String soundId,
    required bool vibrate,
    required bool snoozeEnabled,
    required int snoozeMinutes,
  });

  Future<void> cancelAlarm(String id);

  Future<void> cancelAllAlarms();
}
