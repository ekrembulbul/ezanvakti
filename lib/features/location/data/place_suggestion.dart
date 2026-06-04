import '../../../core/models/location.dart';

/// Photon (OpenStreetMap) arama sonucundaki tek bir yer önerisi.
///
/// Namaz vakti hesabı yalnızca koordinata bağlı olduğundan; `province`/`district`
/// alanları kullanıcıya gösterilen etikettir, `latitude`/`longitude` ise vakit
/// hesabının asıl girdisidir.
class PlaceSuggestion {
  final String id;
  final String name;
  final String province;
  final String district;
  final String country;

  /// ISO 3166-1 alpha-2 ülke kodu (ör. "TR"). Bölgesel varsayılan hesaplama
  /// ayarı için kullanılır; bilinmiyorsa boş.
  final String countryCode;
  final double latitude;
  final double longitude;

  const PlaceSuggestion({
    required this.id,
    required this.name,
    required this.province,
    required this.district,
    required this.country,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
  });

  /// Listede gösterilecek okunur etiket, ör. "Kadıköy, İstanbul, Türkiye".
  /// Tekrar eden parçalar (name == district gibi) ayıklanır.
  String get displayLabel {
    final parts = <String>[];
    for (final part in [name, district, province, country]) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty && !parts.contains(trimmed)) {
        parts.add(trimmed);
      }
    }
    return parts.join(', ');
  }

  /// Kaydedilebilir uygulama konumuna çevirir. Hesaplama parametreleri
  /// (method/school) çağıran tarafça ayarlanır; burada varsayılan kalır.
  Location toLocation() {
    return Location(
      id: id,
      province: province,
      district: district,
      latitude: latitude,
      longitude: longitude,
      type: LocationType.manual,
    );
  }

  /// Photon GeoJSON `feature` özelliklerinden bir öneri üretir.
  /// Kullanılabilir bir etiket veya koordinat yoksa null döner.
  static PlaceSuggestion? fromPhotonFeature(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final coordinates = geometry?['coordinates'] as List<dynamic>?;
    if (coordinates == null || coordinates.length < 2) return null;

    final longitude = (coordinates[0] as num?)?.toDouble();
    final latitude = (coordinates[1] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;

    final props = feature['properties'] as Map<String, dynamic>? ?? const {};
    String read(String key) => (props[key] as String?)?.trim() ?? '';

    final name = read('name');
    final state = read('state');
    final county = read('county');
    final city = read('city');
    final country = read('country');
    final countryCode = read('countrycode');

    final province = state.isNotEmpty
        ? state
        : (county.isNotEmpty ? county : country);
    final district = name.isNotEmpty ? name : (city.isNotEmpty ? city : county);

    if (province.isEmpty && district.isEmpty) return null;

    return PlaceSuggestion(
      id: _buildId(props, latitude, longitude),
      name: name.isNotEmpty ? name : district,
      province: province,
      district: district.isNotEmpty ? district : province,
      country: country,
      countryCode: countryCode.toUpperCase(),
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Önbellek anahtarı olarak kullanılabilecek kararlı bir kimlik üretir:
  /// mümkünse OSM kimliği, yoksa koordinattan türetilir.
  static String _buildId(
    Map<String, dynamic> props,
    double latitude,
    double longitude,
  ) {
    final osmType = (props['osm_type'] as String?)?.trim();
    final osmId = props['osm_id'];
    if (osmType != null && osmType.isNotEmpty && osmId != null) {
      return 'photon-$osmType$osmId';
    }
    return 'geo-${latitude.toStringAsFixed(5)}_${longitude.toStringAsFixed(5)}';
  }
}
