import '../utils/time_formatter.dart';

/// Uygulama geneli davranış tercihleri. `settings` tablosunda anahtar-değer
/// olarak saklanır (bkz. [AppearanceSettings] kalıbı).
class GeneralSettings {
  static const String timeFormatKey = 'general_time_format';
  static const String autoLocationKey = 'general_auto_location';

  /// Saatlerin 12/24 gösterimi.
  final TimeFormatPreference timeFormat;

  /// Açıkken konum GPS ile izlenir ve şehir değişince vakitler tazelenir.
  final bool autoLocation;

  const GeneralSettings({
    this.timeFormat = TimeFormatPreference.system,
    this.autoLocation = true,
  });

  GeneralSettings copyWith({
    TimeFormatPreference? timeFormat,
    bool? autoLocation,
  }) {
    return GeneralSettings(
      timeFormat: timeFormat ?? this.timeFormat,
      autoLocation: autoLocation ?? this.autoLocation,
    );
  }

  Map<String, String> toMap() => {
    timeFormatKey: timeFormat.storageValue,
    autoLocationKey: autoLocation.toString(),
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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeneralSettings &&
          runtimeType == other.runtimeType &&
          timeFormat == other.timeFormat &&
          autoLocation == other.autoLocation;

  @override
  int get hashCode => Object.hash(timeFormat, autoLocation);
}
