import 'calculation_params.dart';
import 'notification_setting.dart' show PrayerType;

/// Uygulama genelindeki **varsayılan** namaz vakti hesaplama ayarları.
///
/// Her konum bu varsayılanı miras alır; konum kendi değerini (override)
/// belirtmediği sürece (bkz. `Location.method`/`school`/`latitudeAdjustmentMethod`
/// alanlarının `null` olması) bu ayar kullanılır.
class CalculationSettings {
  /// Aladhan hesaplama yöntemi (otorite). Bkz. [CalculationMethods].
  final int method;

  /// Aladhan İkindi mezhebi: 0=Şafi/standart, 1=Hanefi.
  final int school;

  /// Yüksek enlem düzeltmesi (1/2/3) veya API varsayılanı için null.
  final int? latitudeAdjustmentMethod;

  /// Vakit başına ± dakika düzeltmesi. Kullanıcı, hesaplanan vakitle elindeki
  /// takvim arasındaki küçük farkı bununla kapatır. Yerelde uygulanır
  /// (bkz. `PrayerTimeTuner`); sıfır değerler saklanmaz.
  final Map<PrayerType, int> tune;

  const CalculationSettings({
    required this.method,
    required this.school,
    this.latitudeAdjustmentMethod,
    this.tune = const {},
  });

  /// Türkiye odaklı varsayılan: Diyanet + standart/Şafi İkindi.
  static const CalculationSettings defaults = CalculationSettings(
    method: CalculationDefaults.method,
    school: CalculationDefaults.school,
  );

  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'school': school,
      'latitudeAdjustmentMethod': latitudeAdjustmentMethod,
      if (tune.isNotEmpty)
        'tune': {
          for (final entry in tune.entries)
            if (entry.value != 0) entry.key.name: entry.value,
        },
    };
  }

  factory CalculationSettings.fromJson(Map<String, dynamic> json) {
    return CalculationSettings(
      method: json['method'] as int? ?? CalculationDefaults.method,
      school: json['school'] as int? ?? CalculationDefaults.school,
      latitudeAdjustmentMethod: json['latitudeAdjustmentMethod'] as int?,
      tune: _tuneFromJson(json['tune']),
    );
  }

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

  CalculationSettings copyWith({
    int? method,
    int? school,
    int? latitudeAdjustmentMethod,
    Map<PrayerType, int>? tune,
  }) {
    return CalculationSettings(
      method: method ?? this.method,
      school: school ?? this.school,
      latitudeAdjustmentMethod:
          latitudeAdjustmentMethod ?? this.latitudeAdjustmentMethod,
      tune: tune ?? this.tune,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalculationSettings &&
          runtimeType == other.runtimeType &&
          method == other.method &&
          school == other.school &&
          latitudeAdjustmentMethod == other.latitudeAdjustmentMethod &&
          _sameTune(tune, other.tune);

  static bool _sameTune(Map<PrayerType, int> a, Map<PrayerType, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    method,
    school,
    latitudeAdjustmentMethod,
    Object.hashAllUnordered([
      for (final entry in tune.entries) Object.hash(entry.key, entry.value),
    ]),
  );
}
