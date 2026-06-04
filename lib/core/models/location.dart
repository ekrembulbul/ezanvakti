import 'calculation_settings.dart';

enum LocationType {
  gps,
  manual;

  String get displayName {
    switch (this) {
      case LocationType.gps:
        return 'GPS Konumu';
      case LocationType.manual:
        return 'Manuel';
    }
  }
}

class Location {
  final String id;
  final String province;
  final String district;
  final double? latitude;
  final double? longitude;
  final LocationType type;
  final String? customName;

  /// Konuma özel hesaplama yöntemi override'ı. `null` ise global ayar kullanılır.
  final int? method;

  /// Konuma özel İkindi mezhebi override'ı (0=Şafi, 1=Hanefi). `null` ise global.
  final int? school;

  /// Konuma özel yüksek enlem düzeltmesi override'ı. `null` ise global ayar.
  final int? latitudeAdjustmentMethod;

  const Location({
    required this.id,
    required this.province,
    required this.district,
    this.latitude,
    this.longitude,
    this.type = LocationType.manual,
    this.customName,
    this.method,
    this.school,
    this.latitudeAdjustmentMethod,
  });

  /// Bu konumun override'larını global [settings] ile birleştirip somut
  /// (null olmayan method/school) bir konum döner. Önbellek kimliği değişmez;
  /// yalnızca hesaplama parametreleri çözümlenir.
  Location withResolvedParams(CalculationSettings settings) {
    return copyWith(
      method: method ?? settings.method,
      school: school ?? settings.school,
      latitudeAdjustmentMethod:
          latitudeAdjustmentMethod ?? settings.latitudeAdjustmentMethod,
    );
  }

  /// Bu konum kendi hesaplama parametrelerini (override) belirtmiş mi?
  bool get hasCalculationOverride =>
      method != null || school != null || latitudeAdjustmentMethod != null;

  String get displayName {
    if (customName != null && customName!.isNotEmpty) {
      return customName!;
    }
    return '$province / $district';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'province': province,
      'district': district,
      'latitude': latitude,
      'longitude': longitude,
      'type': type.name,
      'customName': customName,
      'method': method,
      'school': school,
      'latitudeAdjustmentMethod': latitudeAdjustmentMethod,
    };
  }

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] as String,
      province: json['province'] as String,
      district: json['district'] as String,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      type: LocationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LocationType.manual,
      ),
      customName: json['customName'] as String?,
      // null = override yok, global ayar kullanılır.
      method: json['method'] as int?,
      school: json['school'] as int?,
      latitudeAdjustmentMethod: json['latitudeAdjustmentMethod'] as int?,
    );
  }

  Location copyWith({
    String? id,
    String? province,
    String? district,
    double? latitude,
    double? longitude,
    LocationType? type,
    String? customName,
    int? method,
    int? school,
    int? latitudeAdjustmentMethod,
  }) {
    return Location(
      id: id ?? this.id,
      province: province ?? this.province,
      district: district ?? this.district,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
      customName: customName ?? this.customName,
      method: method ?? this.method,
      school: school ?? this.school,
      latitudeAdjustmentMethod:
          latitudeAdjustmentMethod ?? this.latitudeAdjustmentMethod,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Location &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          province == other.province &&
          district == other.district &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          type == other.type &&
          customName == other.customName &&
          method == other.method &&
          school == other.school &&
          latitudeAdjustmentMethod == other.latitudeAdjustmentMethod;

  @override
  int get hashCode => Object.hash(
    id,
    province,
    district,
    latitude,
    longitude,
    type,
    customName,
    method,
    school,
    latitudeAdjustmentMethod,
  );

  @override
  String toString() => displayName;
}
