/// Konumun nasıl eklendiği. Görünen adı [AppLocalizations] tarafında
/// (`locationTypeLabel`) yaşar; model çeviri taşımaz.
enum LocationType { gps, manual }

class Location {
  final String id;
  final String province;
  final String district;
  final double? latitude;
  final double? longitude;
  final LocationType type;
  final String? customName;

  /// Diyanet ilçe kimliği (`vakit-api` `cityId`). `null` = henüz eşlenmemiş
  /// (eski kayıt); vakit çekilemez, migrasyon bekler.
  final int? cityId;

  /// Diyanet il kimliği.
  final int? stateId;

  /// Diyanet ülke kimliği (Türkiye = 2).
  final int? countryId;

  /// Sunucunun ürettiği görünen ad ("Şile, İstanbul" / "İstanbul (Merkez)").
  final String? displayLabel;

  const Location({
    required this.id,
    required this.province,
    required this.district,
    this.latitude,
    this.longitude,
    this.type = LocationType.manual,
    this.customName,
    this.cityId,
    this.stateId,
    this.countryId,
    this.displayLabel,
  });

  /// Konum bir Diyanet ilçesine bağlı mı?
  bool get isMapped => cityId != null;

  /// Kullanıcıya gösterilen ad, ör. "Kadıköy, İstanbul".
  ///
  /// Öncelik: kullanıcının özel adı → sunucunun `displayLabel`'ı ("Şile,
  /// İstanbul" / "İstanbul (Merkez)") → "ilçe, il" birleşimi. Yedek yolda il
  /// merkezinde iki alan aynı gelirse ("Ankara", "Ankara") tek ad yazılır.
  String get displayName {
    if (customName != null && customName!.isNotEmpty) {
      return customName!;
    }
    if (displayLabel != null && displayLabel!.isNotEmpty) {
      return displayLabel!;
    }

    final parts = <String>[];
    for (final part in [district, province]) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty && !parts.contains(trimmed)) parts.add(trimmed);
    }
    return parts.join(', ');
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
      'cityId': cityId,
      'stateId': stateId,
      'countryId': countryId,
      'displayLabel': displayLabel,
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
      // Eski JSON'daki method/school/latitudeAdjustmentMethod yok sayılır.
      cityId: json['cityId'] as int?,
      stateId: json['stateId'] as int?,
      countryId: json['countryId'] as int?,
      displayLabel: json['displayLabel'] as String?,
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
    int? cityId,
    int? stateId,
    int? countryId,
    String? displayLabel,
  }) {
    return Location(
      id: id ?? this.id,
      province: province ?? this.province,
      district: district ?? this.district,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
      customName: customName ?? this.customName,
      cityId: cityId ?? this.cityId,
      stateId: stateId ?? this.stateId,
      countryId: countryId ?? this.countryId,
      displayLabel: displayLabel ?? this.displayLabel,
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
          cityId == other.cityId &&
          stateId == other.stateId &&
          countryId == other.countryId &&
          displayLabel == other.displayLabel;

  @override
  int get hashCode => Object.hash(
    id,
    province,
    district,
    latitude,
    longitude,
    type,
    customName,
    cityId,
    stateId,
    countryId,
    displayLabel,
  );

  @override
  String toString() => displayName;
}
