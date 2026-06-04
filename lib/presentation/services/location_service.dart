import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' hide Location;
import '../../core/models/location.dart';
import '../../features/location/data/gps_label.dart';

/// Cihazın mevcut GPS konumunu ham koordinat + okunur il/ilçe etiketine çözer.
/// Namaz vakti koordinattan hesaplandığı için adres yalnızca etikettir.
class GpsLocationService {
  // GPS konumu tek satır olarak saklanır; sabit kimlik yeterli.
  static const String _gpsLocationId = 'gps';

  Future<Location> getCurrentGpsLocation() async {
    final hasPermission = await Geolocator.checkPermission();
    if (hasPermission != LocationPermission.always &&
        hasPermission != LocationPermission.whileInUse) {
      throw Exception('Konum izni gerekli');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    final label = placemarks.isNotEmpty
        ? resolveGpsLabel(placemarks.first)
        : (
            province: 'GPS Konumu',
            district:
                '${position.latitude.toStringAsFixed(3)}, '
                '${position.longitude.toStringAsFixed(3)}',
          );

    return Location(
      id: _gpsLocationId,
      province: label.province,
      district: label.district,
      latitude: position.latitude,
      longitude: position.longitude,
      type: LocationType.gps,
    );
  }
}
