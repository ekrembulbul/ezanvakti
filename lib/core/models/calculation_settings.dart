import 'calculation_params.dart';

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

  const CalculationSettings({
    required this.method,
    required this.school,
    this.latitudeAdjustmentMethod,
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
    };
  }

  factory CalculationSettings.fromJson(Map<String, dynamic> json) {
    return CalculationSettings(
      method: json['method'] as int? ?? CalculationDefaults.method,
      school: json['school'] as int? ?? CalculationDefaults.school,
      latitudeAdjustmentMethod: json['latitudeAdjustmentMethod'] as int?,
    );
  }

  CalculationSettings copyWith({
    int? method,
    int? school,
    int? latitudeAdjustmentMethod,
  }) {
    return CalculationSettings(
      method: method ?? this.method,
      school: school ?? this.school,
      latitudeAdjustmentMethod:
          latitudeAdjustmentMethod ?? this.latitudeAdjustmentMethod,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalculationSettings &&
          runtimeType == other.runtimeType &&
          method == other.method &&
          school == other.school &&
          latitudeAdjustmentMethod == other.latitudeAdjustmentMethod;

  @override
  int get hashCode => Object.hash(method, school, latitudeAdjustmentMethod);
}
