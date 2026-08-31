import '../constants/notification_sounds.dart';
import '../utils/time_formatter.dart';

/// Uygulama geneli davranış tercihleri. `settings` tablosunda anahtar-değer
/// olarak saklanır (bkz. [AppearanceSettings] kalıbı).
class GeneralSettings {
  static const String timeFormatKey = 'general_time_format';
  static const String autoLocationKey = 'general_auto_location';
  static const String showInFocusModeKey = 'general_show_in_focus_mode';
  static const String defaultSoundKey = 'general_default_sound';

  /// Saatlerin 12/24 gösterimi.
  final TimeFormatPreference timeFormat;

  /// Açıkken konum GPS ile izlenir ve şehir değişince vakitler tazelenir.
  final bool autoLocation;

  /// Açıkken bildirimler Odak modunda özete düşmez, anında gösterilir.
  /// Sessiz anahtarını delmez.
  final bool showInFocusMode;

  /// Yeni eklenen bildirimlerin varsayılan sesi (`NotificationSounds`).
  final String defaultSound;

  const GeneralSettings({
    this.timeFormat = TimeFormatPreference.system,
    this.autoLocation = true,
    this.showInFocusMode = true,
    this.defaultSound = NotificationSounds.system,
  });

  GeneralSettings copyWith({
    TimeFormatPreference? timeFormat,
    bool? autoLocation,
    bool? showInFocusMode,
    String? defaultSound,
  }) {
    return GeneralSettings(
      timeFormat: timeFormat ?? this.timeFormat,
      autoLocation: autoLocation ?? this.autoLocation,
      showInFocusMode: showInFocusMode ?? this.showInFocusMode,
      defaultSound: defaultSound ?? this.defaultSound,
    );
  }

  Map<String, String> toMap() => {
    timeFormatKey: timeFormat.storageValue,
    autoLocationKey: autoLocation.toString(),
    showInFocusModeKey: showInFocusMode.toString(),
    defaultSoundKey: defaultSound,
  };

  /// Eksik ya da bozuk kayıtlar varsayılana düşer.
  factory GeneralSettings.fromMap(Map<String, String> map) {
    const defaults = GeneralSettings();
    return GeneralSettings(
      timeFormat: TimeFormatPreference.fromStorage(map[timeFormatKey]),
      autoLocation: switch (map[autoLocationKey]) {
        'true' => true,
        'false' => false,
        _ => defaults.autoLocation,
      },
      showInFocusMode: switch (map[showInFocusModeKey]) {
        'true' => true,
        'false' => false,
        _ => defaults.showInFocusMode,
      },
      defaultSound: NotificationSounds.all.contains(map[defaultSoundKey])
          ? map[defaultSoundKey]!
          : defaults.defaultSound,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeneralSettings &&
          runtimeType == other.runtimeType &&
          timeFormat == other.timeFormat &&
          autoLocation == other.autoLocation &&
          showInFocusMode == other.showInFocusMode &&
          defaultSound == other.defaultSound;

  @override
  int get hashCode =>
      Object.hash(timeFormat, autoLocation, showInFocusMode, defaultSound);
}
