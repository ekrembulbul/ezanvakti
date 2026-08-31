import 'package:intl/intl.dart';

/// Kullanıcının saat gösterim tercihi.
enum TimeFormatPreference {
  /// Cihazın 24/12 saat ayarına uyar.
  system('system', 'Sistem'),
  h24('h24', '24 saat'),
  h12('h12', '12 saat');

  const TimeFormatPreference(this.storageValue, this.label);

  /// `settings` tablosunda saklanan kararlı değer; enum adı değişse de
  /// kayıtlar bozulmasın diye ayrı tutuluyor.
  final String storageValue;
  final String label;

  static TimeFormatPreference fromStorage(String? value) {
    for (final preference in values) {
      if (preference.storageValue == value) return preference;
    }
    return system;
  }
}

/// Saatleri kullanıcının tercihine göre biçimlendirir.
///
/// Sistem tercihi dışarıdan [systemUses24h] ile verilir (Flutter'da
/// `MediaQuery.alwaysUse24HourFormatOf(context)`); böylece bu sınıf saf kalır
/// ve test edilebilir.
class TimeFormatter {
  const TimeFormatter._();

  static String format(
    DateTime time,
    TimeFormatPreference preference, {
    required bool systemUses24h,
  }) {
    return _uses24h(preference, systemUses24h)
        ? DateFormat('HH:mm').format(time)
        : DateFormat('h:mm a').format(time);
  }

  /// Saat/dakika çiftinden biçimlendirir (tarihi olmayan alarm saatleri için).
  static String formatHourMinute(
    int hour,
    int minute,
    TimeFormatPreference preference, {
    required bool systemUses24h,
  }) {
    return format(
      DateTime(2000, 1, 1, hour, minute),
      preference,
      systemUses24h: systemUses24h,
    );
  }

  static bool _uses24h(TimeFormatPreference preference, bool systemUses24h) =>
      switch (preference) {
        TimeFormatPreference.system => systemUses24h,
        TimeFormatPreference.h24 => true,
        TimeFormatPreference.h12 => false,
      };
}
