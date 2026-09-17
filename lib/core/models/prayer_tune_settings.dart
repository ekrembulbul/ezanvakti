import 'notification_setting.dart' show PrayerType;

/// Vakit başına ± dakika düzeltmesi (kullanıcı ayarı).
///
/// Diyanet tablosu hesap değil veridir; kullanıcının değiştirebildiği tek şey
/// bu kaydırmadır. Yerelde, okuma anında uygulanır (bkz. `PrayerTimeTuner`,
/// ADR 0004); sıfır değerler saklanmaz.
///
/// Depo anahtarı geçmişten `calculation_settings` olarak kalır: eski JSON'daki
/// `method`/`school` alanları yok sayılır, `tune` korunur.
class PrayerTuneSettings {
  final Map<PrayerType, int> tune;

  const PrayerTuneSettings({this.tune = const {}});

  static const PrayerTuneSettings none = PrayerTuneSettings();

  Map<String, dynamic> toJson() => {
    if (tune.isNotEmpty)
      'tune': {
        for (final entry in tune.entries)
          if (entry.value != 0) entry.key.name: entry.value,
      },
  };

  factory PrayerTuneSettings.fromJson(Map<String, dynamic> json) =>
      PrayerTuneSettings(tune: _tuneFromJson(json['tune']));

  static Map<PrayerType, int> _tuneFromJson(Object? raw) {
    if (raw is! Map) return const {};
    final result = <PrayerType, int>{};
    for (final entry in raw.entries) {
      final minutes = entry.value;
      if (minutes is! int || minutes == 0) continue;
      for (final type in PrayerType.values) {
        if (type.name == entry.key) result[type] = minutes;
      }
    }
    return result;
  }

  PrayerTuneSettings copyWith({Map<PrayerType, int>? tune}) =>
      PrayerTuneSettings(tune: tune ?? this.tune);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerTuneSettings &&
          runtimeType == other.runtimeType &&
          _sameTune(tune, other.tune);

  static bool _sameTune(Map<PrayerType, int> a, Map<PrayerType, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered([
    for (final entry in tune.entries) Object.hash(entry.key, entry.value),
  ]);
}
