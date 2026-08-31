import 'dart:ui';

/// Kullanıcının dil tercihi. [system] cihaz dilini izler; desteklenmeyen bir
/// cihaz dilinde uygulama Türkçe'ye düşer (kaynak dil).
enum AppLanguage {
  system('system'),
  turkish('tr'),
  english('en'),
  arabic('ar');

  const AppLanguage(this.storageValue);

  /// `settings` tablosunda saklanan kararlı değer.
  final String storageValue;

  /// `MaterialApp.locale` değeri; [system] için null (cihaz dili kullanılır).
  Locale? get locale =>
      this == AppLanguage.system ? null : Locale(storageValue);

  static AppLanguage fromStorage(String? value) {
    for (final language in AppLanguage.values) {
      if (language.storageValue == value) return language;
    }
    return AppLanguage.system;
  }
}
