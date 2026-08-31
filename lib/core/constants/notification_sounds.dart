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

  /// Kullanıcıya görünen ad; tanınmayan değer varsayılana düşer.
  static String labelFor(String? soundId) => switch (soundId) {
    beep => 'Kısa uyarı',
    silent => 'Sessiz',
    _ => 'Sistem sesi',
  };
}
