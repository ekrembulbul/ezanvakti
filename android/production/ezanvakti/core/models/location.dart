class Location {
  final String id;
  final String province;
  final String district;
  final double? latitude;
  final double? longitude;

  const Location({
    required this.id,
    required this.province,
    required this.district,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'province': province,
      'district': district,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] as String,
      province: json['province'] as String,
      district: json['district'] as String,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
    );
  }

  @override
  String toString() => '$province / $district';
}
