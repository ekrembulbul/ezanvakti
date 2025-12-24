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

  Future<List<Location>> getSavedLocations() async {
    return await storage.getSavedLocations();
  }

  Future<void> saveLocation(Location location) async {
    await storage.saveLocation(location);
  }

  Future<void> deleteLocation(String locationId) async {
    await storage.deleteLocation(locationId);
  }

  Future<void> updateLocation(Location location) async {
    await storage.updateLocation(location);
  }

  Future<Location?> getGpsLocation() async {
    final locations = await storage.getSavedLocations();
    return locations.where((loc) => loc.type == LocationType.gps).firstOrNull;
  }

  Future<Location> saveOrUpdateGpsLocation(Location location) async {
    final existingGps = await getGpsLocation();
    if (existingGps != null) {
      final updatedLocation = location.copyWith(id: existingGps.id);
      await storage.updateLocation(updatedLocation);
      return updatedLocation;
    } else {
      await storage.saveLocation(location);
      return location;
    }
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
