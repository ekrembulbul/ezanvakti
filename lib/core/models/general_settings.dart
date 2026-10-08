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
  static const String ramadanModeKey = 'general_ramadan_mode';
  static const String alarmRingLimitKey = 'general_alarm_ring_limit';

  /// Seçenekler (dakika); 0 = sınırsız.
  static const List<int> alarmRingLimitOptions = [5, 10, 15, 30, 0];

  static const String nextPrayerNotificationKey =
      'general_next_prayer_notification';

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

  /// Ramazan'da arayüz iftar/sahur odaklı hale gelsin mi.
  final bool ramadanMode;

  /// Kapatılmayan alarm bu kadar dakika sonra ertelenir ya da susar
  /// (yalnız Android). 0 = sınırsız.
  final int alarmRingLimitMinutes;

  /// Bildirim çubuğunda sabit "sıradaki vakit" satırı (yalnız Android).
  /// Bildirim izni varsa açık gelir.
  final bool nextPrayerNotification;

  const GeneralSettings({
    this.timeFormat = TimeFormatPreference.system,
    this.autoLocation = true,
    this.showInFocusMode = true,
    this.defaultSound = NotificationSounds.system,
    this.religiousDayNotifications = false,
    this.religiousDayEve = true,
    this.ramadanMode = true,
    this.alarmRingLimitMinutes = 10,
    this.nextPrayerNotification = true,
  });

  GeneralSettings copyWith({
    TimeFormatPreference? timeFormat,
    bool? autoLocation,
    bool? showInFocusMode,
    String? defaultSound,
    bool? religiousDayNotifications,
    bool? religiousDayEve,
    bool? ramadanMode,
    int? alarmRingLimitMinutes,
    bool? nextPrayerNotification,
  }) {
    return GeneralSettings(
      timeFormat: timeFormat ?? this.timeFormat,
      autoLocation: autoLocation ?? this.autoLocation,
      showInFocusMode: showInFocusMode ?? this.showInFocusMode,
      defaultSound: defaultSound ?? this.defaultSound,
      religiousDayNotifications:
          religiousDayNotifications ?? this.religiousDayNotifications,
      religiousDayEve: religiousDayEve ?? this.religiousDayEve,
      ramadanMode: ramadanMode ?? this.ramadanMode,
      alarmRingLimitMinutes:
          alarmRingLimitMinutes ?? this.alarmRingLimitMinutes,
      nextPrayerNotification:
          nextPrayerNotification ?? this.nextPrayerNotification,
    );
  }

  Map<String, String> toMap() => {
    timeFormatKey: timeFormat.storageValue,
    autoLocationKey: autoLocation.toString(),
    showInFocusModeKey: showInFocusMode.toString(),
    defaultSoundKey: defaultSound,
    religiousDaysKey: religiousDayNotifications.toString(),
    religiousDayEveKey: religiousDayEve.toString(),
    ramadanModeKey: ramadanMode.toString(),
    alarmRingLimitKey: alarmRingLimitMinutes.toString(),
    nextPrayerNotificationKey: nextPrayerNotification.toString(),
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
      ramadanMode: switch (map[ramadanModeKey]) {
        'true' => true,
        'false' => false,
        _ => defaults.ramadanMode,
      },
      alarmRingLimitMinutes: switch (int.tryParse(
        map[alarmRingLimitKey] ?? '',
      )) {
        final value? when alarmRingLimitOptions.contains(value) => value,
        _ => defaults.alarmRingLimitMinutes,
      },
      nextPrayerNotification: switch (map[nextPrayerNotificationKey]) {
        'true' => true,
        'false' => false,
        _ => defaults.nextPrayerNotification,
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
          religiousDayEve == other.religiousDayEve &&
          ramadanMode == other.ramadanMode &&
          alarmRingLimitMinutes == other.alarmRingLimitMinutes &&
          nextPrayerNotification == other.nextPrayerNotification;

  @override
  int get hashCode => Object.hash(
    timeFormat,
    autoLocation,
    showInFocusMode,
    defaultSound,
    religiousDayNotifications,
    religiousDayEve,
    ramadanMode,
    alarmRingLimitMinutes,
    nextPrayerNotification,
  );
}
