import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/location.dart';
import '../data/turkey_locations_data.dart';

class LocationRepository {
  final LocalStorage storage;

  LocationRepository({required this.storage});

  Future<Location?> getActiveLocation() async {
    return await storage.getActiveLocation();
  }

  Future<void> setActiveLocation(Location location) async {
    await storage.saveActiveLocation(location);
  }

  List<String> getAllProvinces() {
    return TurkeyLocationsData.getAllProvinces();
  }

  List<Location> getDistrictsByProvince(String province) {
    return TurkeyLocationsData.getDistrictsByProvince(province);
  }

  Location? getLocationById(String id) {
    return TurkeyLocationsData.getLocationById(id);
  }

  List<Location> getAllLocations() {
    return TurkeyLocationsData.getAllLocations();
  }

  List<Location> searchLocations(String query) {
    return TurkeyLocationsData.searchLocations(query);
  }
}
