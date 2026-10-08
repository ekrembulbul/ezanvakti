/// Bildirim sesi kimlikleri.
///
/// `null` (ayarda ses seçilmemiş) sistem varsayılanı demektir; buradaki
/// değerler yalnızca kullanıcının açıkça seçtiği durumlar için.
class NotificationSounds {
  const NotificationSounds._();

  /// Sistemin varsayılan bildirim sesi.
  static const String system = 'system';

  /// Uygulamanın kendi kısa uyarı tonu (`ios/Runner/Sounds/beep.caf`).
  static const String beep = 'beep';

  /// Ses yok — bildirim yalnızca görsel.
  static const String silent = 'silent';

  static const List<String> all = [system, beep, silent];

  /// iOS bundle'daki dosya adı; sistem/sessiz için `null`.
  static String? fileFor(String? soundId) =>
      soundId == beep ? 'beep.caf' : null;

  static bool isSilent(String? soundId) => soundId == silent;

  /// Android bildirim kanalları. Kanal sesi oluşturulduktan sonra
  /// değişmediği için ses başına ayrı kanal var. Sistem kanalı eski tek
  /// kanalın kimliğini korur: kullanıcının sistem ayarlarında yaptığı
  /// değişiklikler o kanalda.
  static const String androidSystemChannel = 'ezan_vakti_channel';
  static const String androidBeepChannel = 'ezan_vakti_beep';
  static const String androidSilentChannel = 'ezan_vakti_silent';

  /// `res/raw/beep.wav`.
  static const String androidBeepResource = 'beep';

  static String androidChannelFor(String? soundId, {required bool silent}) {
    if (silent || isSilent(soundId)) return androidSilentChannel;
    if (soundId == beep) return androidBeepChannel;
    return androidSystemChannel;
  }
}
