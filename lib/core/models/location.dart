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

  const Location({
    required this.id,
    required this.province,
    required this.district,
    this.latitude,
    this.longitude,
    this.type = LocationType.manual,
    this.customName,
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
  }) {
    return Location(
      id: id ?? this.id,
      province: province ?? this.province,
      district: district ?? this.district,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
      customName: customName ?? this.customName,
    );
  }

  @override
  String toString() => displayName;
}
