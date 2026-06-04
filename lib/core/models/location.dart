import 'calculation_params.dart';

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

  /// Aladhan hesaplama yöntemi (otorite) — konuma özel.
  final int method;

  /// Aladhan İkindi mezhebi (0=Şafi, 1=Hanefi) — konuma özel.
  final int school;

  /// Yüksek enlem düzeltmesi (1/2/3) veya API varsayılanı için null.
  final int? latitudeAdjustmentMethod;

  const Location({
    required this.id,
    required this.province,
    required this.district,
    this.latitude,
    this.longitude,
    this.type = LocationType.manual,
    this.customName,
    this.method = CalculationDefaults.method,
    this.school = CalculationDefaults.school,
    this.latitudeAdjustmentMethod,
  });

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
      // Eski kayıtlarda bu alanlar yoktur; güvenli varsayılana düşülür.
      method: json['method'] as int? ?? CalculationDefaults.method,
      school: json['school'] as int? ?? CalculationDefaults.school,
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
