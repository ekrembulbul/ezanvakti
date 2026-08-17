import '../models/alarm_mission.dart';
import '../models/alarm_theme.dart';
import '../models/mission_stop_event.dart';

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
  ///
  /// [theme] çalar ekranının renkleridir; alarmın çalacağı anın dilimine göre
  /// planlama sırasında hesaplanır.
  Future<void> scheduleAlarm({
    required String id,
    required DateTime scheduledTime,
    required String label,
    required String soundId,
    required bool vibrate,
    required bool snoozeEnabled,
    required int snoozeMinutes,
    required AlarmTheme theme,
    required AlarmMission mission,
    required int missionLevel,
    required Map<String, dynamic> chainConfig,
  });

  Future<void> cancelAlarm(String id);

  Future<void> cancelAllAlarms();

  /// Kullanıcının seçtiği ses dosyasını ([sourcePath]) uygulamanın kalıcı alanına
  /// kopyalar ve alarmlarda kullanılacak `custom:<ad>` biçiminde bir soundId döner.
  /// Başarısızsa veya platform desteklemiyorsa null döner.
  ///
  /// iOS notu: AlarmKit yalnızca desteklenen ses biçimlerini (caf/aiff/wav,
  /// ≤30 sn) çalar; diğer biçimler sessizce varsayılan sese düşebilir.
  Future<String?> importCustomSound(String sourcePath);

  /// Uygulama **ayaktayken** gelen "alarm durduruldu" bildirimleri.
  ///
  /// Kuyruk tek başına yetmiyor: ön plandaki uygulamada hiçbir yaşam döngüsü
  /// olayı tetiklenmediği için görev ekranı hiç açılmıyordu.
  Stream<MissionStopEvent> get missionStops;

  /// `stopIntent` tarafından biriktirilen olayları okur ve kuyruğu boşaltır.
  Future<List<MissionStopEvent>> consumeMissionEvents();

  /// Görev ekranı açıldı: nöbetçinin son tarihi `grace`ten görev süresine
  /// taşınır.
  Future<void> beginMission(String alarmId);

  /// Görev tamamlandı: zincirdeki tüm alarmlar iptal edilir, oturum kapanır.
  Future<void> completeMission(String alarmId);

  /// Acil çıkış: [completeMission] ile aynı temizlik, ayrı raporlanır.
  Future<void> abortMission(String alarmId);
}
