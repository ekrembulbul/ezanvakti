import '../constants/notification_sounds.dart';
import '../utils/time_formatter.dart';

/// Uygulama geneli davranış tercihleri. `settings` tablosunda anahtar-değer
/// olarak saklanır (bkz. [AppearanceSettings] kalıbı).
class GeneralSettings {
  static const String timeFormatKey = 'general_time_format';
  static const String autoLocationKey = 'general_auto_location';
  static const String showInFocusModeKey = 'general_show_in_focus_mode';
  static const String defaultSoundKey = 'general_default_sound';
  static const String religiousDaysKey = 'general_religious_days';
  static const String religiousDayEveKey = 'general_religious_day_eve';

  /// Saatlerin 12/24 gösterimi.
  final TimeFormatPreference timeFormat;

  /// Açıkken konum GPS ile izlenir ve şehir değişince vakitler tazelenir.
  final bool autoLocation;

  /// Açıkken bildirimler Odak modunda özete düşmez, anında gösterilir.
  /// Sessiz anahtarını delmez.
  final bool showInFocusMode;

  /// Yeni eklenen bildirimlerin varsayılan sesi (`NotificationSounds`).
  final String defaultSound;

  /// Kandil, bayram ve diğer dini günlerde bildirim gönderilsin mi.
  final bool religiousDayNotifications;

  /// Açıkken dini günden bir gün önce de hatırlatılır.
  final bool religiousDayEve;

  const GeneralSettings({
    this.timeFormat = TimeFormatPreference.system,
    this.autoLocation = true,
    this.showInFocusMode = true,
    this.defaultSound = NotificationSounds.system,
    this.religiousDayNotifications = false,
    this.religiousDayEve = true,
  });

  GeneralSettings copyWith({
    TimeFormatPreference? timeFormat,
    bool? autoLocation,
    bool? showInFocusMode,
    String? defaultSound,
    bool? religiousDayNotifications,
    bool? religiousDayEve,
  }) {
    return GeneralSettings(
      timeFormat: timeFormat ?? this.timeFormat,
      autoLocation: autoLocation ?? this.autoLocation,
      showInFocusMode: showInFocusMode ?? this.showInFocusMode,
      defaultSound: defaultSound ?? this.defaultSound,
      religiousDayNotifications:
          religiousDayNotifications ?? this.religiousDayNotifications,
      religiousDayEve: religiousDayEve ?? this.religiousDayEve,
    );
  }

  Map<String, String> toMap() => {
    timeFormatKey: timeFormat.storageValue,
    autoLocationKey: autoLocation.toString(),
    showInFocusModeKey: showInFocusMode.toString(),
    defaultSoundKey: defaultSound,
    religiousDaysKey: religiousDayNotifications.toString(),
    religiousDayEveKey: religiousDayEve.toString(),
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
      religiousDayNotifications: switch (map[religiousDaysKey]) {
        'true' => true,
        'false' => false,
        _ => defaults.religiousDayNotifications,
      },
      religiousDayEve: switch (map[religiousDayEveKey]) {
        'true' => true,
        'false' => false,
        _ => defaults.religiousDayEve,
      },
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
          defaultSound == other.defaultSound &&
          religiousDayNotifications == other.religiousDayNotifications &&
          religiousDayEve == other.religiousDayEve;

  @override
  int get hashCode => Object.hash(
    timeFormat,
    autoLocation,
    showInFocusMode,
    defaultSound,
    religiousDayNotifications,
    religiousDayEve,
  );
}
