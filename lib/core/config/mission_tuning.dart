import '../models/alarm_mission.dart';

/// Görev zincirinin kalibrasyon sabitleri.
///
/// Bunlar **kullanıcı ayarı değildir**: Ayarlar ekranında görünmez, ölçümle
/// kalibre edilebilsin diye tek yerde toplanmıştır. Başlangıç değerleri
/// tahmindir; cihazda ölçülüp güncellenecek.
class MissionTuning {
  const MissionTuning._();

  /// Alarm durduruldu ama görev ekranı hiç açılmadı; alarmın dönmesi için
  /// beklenen süre. Durdurup uykuya dönen kullanıcı tam görev süresini
  /// beklemeden yakalanmalı.
  static const int graceSeconds = 20;

  /// Sağlama merdiveni: `stopIntent` hiç çalışmazsa devreye giren, alarm
  /// kurulurken önden dizilen yedekler.
  static const int ladderStepMinutes = 5;
  static const int ladderCount = 3;

  /// Zincirin sert tavanları. İkisinden hangisi önce dolarsa zincir durur —
  /// bir hata sonsuz alarma dönüşmesin.
  ///
  /// CIHAZ TESTI: ilk dogrulama turu icin kasten dusuk. Bir hata olursa
  /// telefon dakikalarla sinirli sure dirdir etsin, saatlerce degil.
  /// Kalibrasyon sonrasi 40 / 60'a cikarilacak.
  static const int maxRearms = 5;
  static const int chainDeadlineMinutes = 10;

  /// Acil çıkış kademesi: tavan ve gerileme.
  static const int abortMaxLevel = 3;
  static const int abortDecayDays = 7;

  /// Görev süresi, tipe göre. Görev ekranı açıldığı anda işlemeye başlar.
  ///
  /// QR en uzun süreyi alır: kodun bulunduğu yere yürümek gerekiyor.
  static const Map<AlarmMission, int> _timeouts = {
    AlarmMission.none: 0,
    AlarmMission.math: 90,
    AlarmMission.shake: 60,
    AlarmMission.qr: 180,
  };

  /// [mission] için görev süresi (sn). [AlarmMission.none] için 0.
  static int timeoutSecondsFor(AlarmMission mission) => _timeouts[mission] ?? 0;
}
