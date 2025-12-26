import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' hide Location;
import '../../core/models/location.dart';
import '../../features/location/domain/location_repository.dart';

class LocationService {
  final LocationRepository _repository;

  LocationService(this._repository);

  Future<Location> getCurrentGpsLocation() async {
    final hasPermission = await Geolocator.checkPermission();
    if (hasPermission != LocationPermission.always &&
        hasPermission != LocationPermission.whileInUse) {
      throw Exception('Konum izni gerekli');
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
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

    final matchedLocation = _findMatchingLocation(province, district);
    if (matchedLocation == null) {
      throw Exception('$province/$district için veri bulunamadı');
    }

    return matchedLocation.copyWith(
      type: LocationType.gps,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Location? _findMatchingLocation(String province, String district) {
    final allProvinces = _repository.getAllProvinces();

    String? matchedProvince;
    for (final p in allProvinces) {
      if (p.toLowerCase().contains(province.toLowerCase()) ||
          province.toLowerCase().contains(p.toLowerCase())) {
        matchedProvince = p;
        break;
      }
    }

    if (matchedProvince == null) return null;

    final districts = _repository.getDistrictsByProvince(matchedProvince);
    for (final d in districts) {
      if (d.district.toLowerCase().contains(district.toLowerCase()) ||
          district.toLowerCase().contains(d.district.toLowerCase())) {
        return d;
      }
    }

    return districts.isNotEmpty ? districts.first : null;
  }
}
