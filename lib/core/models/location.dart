import 'calculation_settings.dart';

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

  /// Konuma özel hesaplama yöntemi override'ı. `null` ise global ayar kullanılır.
  final int? method;

  /// Konuma özel İkindi mezhebi override'ı (0=Şafi, 1=Hanefi). `null` ise global.
  final int? school;

  /// Konuma özel yüksek enlem düzeltmesi override'ı. `null` ise global ayar.
  final int? latitudeAdjustmentMethod;

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
    this.method,
    this.school,
    this.latitudeAdjustmentMethod,
    this.cityId,
    this.stateId,
    this.countryId,
    this.displayLabel,
  });

  /// Konum bir Diyanet ilçesine bağlı mı?
  bool get isMapped => cityId != null;

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

  /// Kullanıcıya gösterilen ad, ör. "Kadıköy, İstanbul".
  ///
  /// Sıra, ayıraç ve tekrar ayıklama, arama listesindeki
  /// `PlaceSuggestion.displayLabel` ile aynı: kullanıcı seçerken
  /// "Kadıköy, İstanbul, Türkiye" görüyor, kaydettikten sonra aynı yerin
  /// farklı sırada görünmesi kafa karıştırıyordu. Ülke adı kayıttan sonra
  /// ayırt edici olmadığı için düşürülür.
  ///
  /// İl merkezlerinde iki alan da aynı geliyor (Photon `name` = `state` =
  /// "Ankara"); "Ankara, Ankara" yerine tek ad gösterilir.
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
      'method': method,
      'school': school,
      'latitudeAdjustmentMethod': latitudeAdjustmentMethod,
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
      // null = override yok, global ayar kullanılır.
      method: json['method'] as int?,
      school: json['school'] as int?,
      latitudeAdjustmentMethod: json['latitudeAdjustmentMethod'] as int?,
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
    int? method,
    int? school,
    int? latitudeAdjustmentMethod,
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
      method: method ?? this.method,
      school: school ?? this.school,
      latitudeAdjustmentMethod:
          latitudeAdjustmentMethod ?? this.latitudeAdjustmentMethod,
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
          method == other.method &&
          school == other.school &&
          latitudeAdjustmentMethod == other.latitudeAdjustmentMethod &&
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
    method,
    school,
    latitudeAdjustmentMethod,
    cityId,
    stateId,
    countryId,
    displayLabel,
  );

  @override
  String toString() => displayName;
}
