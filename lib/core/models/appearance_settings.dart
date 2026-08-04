import '../theme/day_phase.dart';

/// Kullanıcının seçtiği tema modu. [system] cihazın parlaklık tercihini izler.
enum AppThemeMode { dark, light, system }

/// Görünüm tercihleri. `settings` tablosunda anahtar-değer olarak saklanır.
class AppearanceSettings {
  static const String themeModeKey = 'appearance_theme_mode';
  static const String timeBasedColorKey = 'appearance_time_based_color';
  static const String fixedPaletteKey = 'appearance_fixed_palette';

  /// Koyu / açık / sistem.
  final AppThemeMode themeMode;

  /// Açıkken palet gün içinde vakte göre ilerler.
  final bool timeBasedColor;

  /// [timeBasedColor] kapalıyken kullanılacak sabit palet.
  ///
  /// Anahtar açıkken bu değer korunur ama etkisizdir — kullanıcı kapatıp
  /// tekrar açtığında seçimi kaybolmasın diye.
  final DayPhase fixedPalette;

  const AppearanceSettings({
    this.themeMode = AppThemeMode.system,
    this.timeBasedColor = true,
    this.fixedPalette = DayPhase.evening,
  });

  AppearanceSettings copyWith({
    AppThemeMode? themeMode,
    bool? timeBasedColor,
    DayPhase? fixedPalette,
  }) {
    return AppearanceSettings(
      themeMode: themeMode ?? this.themeMode,
      timeBasedColor: timeBasedColor ?? this.timeBasedColor,
      fixedPalette: fixedPalette ?? this.fixedPalette,
    );
  }

  Map<String, String> toMap() {
    return {
      themeModeKey: themeMode.name,
      timeBasedColorKey: timeBasedColor.toString(),
      fixedPaletteKey: fixedPalette.name,
    };
  }

  /// Eksik, boş ya da tanınmayan değerler varsayılana düşer; bozuk bir kayıt
  /// uygulamayı temasız bırakmaz.
  factory AppearanceSettings.fromMap(Map<String, String> map) {
    const defaults = AppearanceSettings();
    return AppearanceSettings(
      themeMode: _enumByName(
        AppThemeMode.values,
        map[themeModeKey],
        defaults.themeMode,
      ),
      timeBasedColor: switch (map[timeBasedColorKey]) {
        'true' => true,
        'false' => false,
        _ => defaults.timeBasedColor,
      },
      fixedPalette: _enumByName(
        DayPhase.values,
        map[fixedPaletteKey],
        defaults.fixedPalette,
      ),
    );
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) {
    return other is AppearanceSettings &&
        other.themeMode == themeMode &&
        other.timeBasedColor == timeBasedColor &&
        other.fixedPalette == fixedPalette;
  }

  @override
  int get hashCode => Object.hash(themeMode, timeBasedColor, fixedPalette);

  @override
  String toString() {
    return 'AppearanceSettings(themeMode: ${themeMode.name}, '
        'timeBasedColor: $timeBasedColor, fixedPalette: ${fixedPalette.name})';
  }
}
