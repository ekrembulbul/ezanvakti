import 'package:geolocator/geolocator.dart';

import '../../../core/models/location.dart';
import 'places_api.dart';

/// GPS akışındaki kararlı hata anahtarı; metni sunum katmanı seçer.
class GpsLocationException implements Exception {
  final String key;

  const GpsLocationException(this.key);

  @override
  String toString() => 'GpsLocationException($key)';
}

class GpsResolution {
  final Location location;
  final double distanceKm;

  const GpsResolution({required this.location, required this.distanceKm});
}

/// Cihaz konumunu alır ve sunucuda Diyanet ilçesine çözer.
///
/// Konum tek satır olarak saklanır (`gps` kimliği); koordinat cihazınki
/// (kıble için), il/ilçe ve `cityId` sunucudan. Ters-geocode yok: cihaz
/// koordinatı platform servislerine değil yalnız `vakit-api`'ye gider.
class GpsLocationService {
  final PlacesApi api;

  static const String gpsLocationId = 'gps';
  static const String servicesOffKey = 'location_services_off';
  static const String permissionRequiredKey = 'location_permission_required';
  static const String permissionDeniedForeverKey =
      'location_permission_denied_forever';

  GpsLocationService({required this.api});

  /// İzin `denied` ise [requestPermission] çağrılır; `true` dönerse sistem izni
  /// istenir. Verilmezse izin yokken [permissionRequiredKey] fırlatılır.
  /// Sunucu hataları ([NoCoverageException], ağ) olduğu gibi çıkar.
  Future<GpsResolution> locate({
    Future<bool> Function()? requestPermission,
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const GpsLocationException(servicesOffKey);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (requestPermission == null || !await requestPermission()) {
        throw const GpsLocationException(permissionRequiredKey);
      }
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const GpsLocationException(permissionRequiredKey);
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const GpsLocationException(permissionDeniedForeverKey);
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return resolve(position.latitude, position.longitude);
  }

  /// Koordinatı sunucuda ilçeye çözer; izleyici ve [locate] aynı yolu kullanır.
  Future<GpsResolution> resolve(
    double latitude,
    double longitude, {
    String? customName,
  }) async {
    final result = await api.resolve(latitude: latitude, longitude: longitude);
    final location = result.city
        .toLocation(
          type: LocationType.gps,
          id: gpsLocationId,
          latitude: latitude,
          longitude: longitude,
        )
        .copyWith(customName: customName);
    return GpsResolution(location: location, distanceKm: result.distanceKm);
  }
}
