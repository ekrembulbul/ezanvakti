import '../models/alarm_mission.dart';

/// Görev zincirinin kalibrasyon sabitleri.
///
/// Bunlar **kullanıcı ayarı değildir**: Ayarlar ekranında görünmez, ölçümle
/// kalibre edilebilsin diye tek yerde toplanmıştır. Başlangıç değerleri
/// tahmindir; cihazda ölçülüp güncellenecek.
class MissionTuning {
  const MissionTuning._();

  /// Görevli alarmda ara ekranda seçim süresi. Alarm durduruldu, kullanıcı
  /// "Görevi yap"a ya da "Ertele"ye basmadı; bu kadar saniye sonra alarm
  /// döner. 20 sn ekranı okuyup basmak için dar geldi (spec 2026-08-30 D12).
  static const int graceSeconds = 30;

  /// Görevsiz alarmda ara ekranın açık kalma süresi. Dolarsa "Tamam" sayılır:
  /// oturum kapanır, alarmlar yeniden kurulur. Ceza yok — görevsizde durdurma
  /// zaten kesin — ama ekran sonsuza kadar da açık kalmasın.
  static const int stopScreenSeconds = 45;

  /// Sağlama merdiveni: `stopIntent` hiç çalışmazsa devreye giren, alarm
  /// kurulurken önden dizilen yedekler.
  static const int ladderStepMinutes = 5;
  static const int ladderCount = 3;

  /// Zincirin sert tavanları. İkisinden hangisi önce dolarsa zincir durur —
  /// bir hata sonsuz alarma dönüşmesin.
  ///
  /// 60 dakika, en inatçı uykucunun bile kalkması için fazlasıyla yeterli bir
  /// pencere; ötesi kullanıcıyı korumaktan çıkıp cezalandırmaya döner.
  static const int maxRearms = 40;
  static const int chainDeadlineMinutes = 60;

  /// Acil çıkış kademesi: tavan ve gerileme.
  static const int abortMaxLevel = 3;
  static const int abortDecayDays = 7;

  /// Görev süresi, tipe göre. Görev ekranı açıldığı anda işlemeye başlar.
  ///
  /// QR önce 120 sn idi (kodun bulunduğu yere yürüme payı); cihazda fazla
  /// uzun geldi, kullanıcı kararıyla 90'a indi — ekranda donmuş gibi duran
  /// bir sayaç güven vermiyor.
  static const Map<AlarmMission, int> _timeouts = {
    AlarmMission.none: 0,
    AlarmMission.math: 90,
    AlarmMission.shake: 60,
    AlarmMission.qr: 90,
  };

  /// [mission] için görev süresi (sn). [AlarmMission.none] için 0.
  static int timeoutSecondsFor(AlarmMission mission) => _timeouts[mission] ?? 0;
}
