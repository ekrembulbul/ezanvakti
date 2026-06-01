import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' hide Location;
import '../../core/models/location.dart';
import '../../features/location/data/turkey_locations_data.dart';

/// Resolves the device's current GPS position to a known Turkey location.
class GpsLocationService {
  Future<Location> getCurrentGpsLocation() async {
    final hasPermission = await Geolocator.checkPermission();
    if (hasPermission != LocationPermission.always &&
        hasPermission != LocationPermission.whileInUse) {
      throw Exception('Konum izni gerekli');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isEmpty) {
      throw Exception('Konum bilgisi alınamadı');
    }

    final placemark = placemarks.first;
    final province = placemark.administrativeArea ?? '';
    final district =
        placemark.subAdministrativeArea ?? placemark.locality ?? '';

    if (province.isEmpty || district.isEmpty) {
      throw Exception('İl veya ilçe bilgisi bulunamadı');
    }

    final matchedLocation = TurkeyLocationsData.findMatchingLocation(
      province,
      district,
    );
    if (matchedLocation == null) {
      throw Exception('$province/$district için veri bulunamadı');
    }

    return matchedLocation.copyWith(
      type: LocationType.gps,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
