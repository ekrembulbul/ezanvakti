import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/location.dart';

class LocationRepository {
  final LocalStorage storage;
  final Future<void> Function(String)? _clearPrayerCache;

  LocationRepository({
    required this.storage,
    Future<void> Function(String)? clearPrayerCache,
  }) : _clearPrayerCache = clearPrayerCache;

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

  /// Bir konumun önbellekteki vakitlerini siler. Yeni bir konum eklenirken
  /// veya konumun ilçesi değişirken çağrılır; bir sonraki yükleme yeniden çeker.
  Future<void> clearPrayerTimeCache(String locationId) async {
    await (_clearPrayerCache?.call(locationId) ??
        storage.deletePrayerTimesForLocation(locationId));
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
      // Vakit ilçeye bağlı: koordinat aynı ilçe içinde oynasa önbellek geçerli.
      if (existingGps.cityId != updatedLocation.cityId) {
        await clearPrayerTimeCache(existingGps.id);
      }
      await storage.updateLocation(updatedLocation);
      return updatedLocation;
    } else {
      await storage.saveLocation(location);
      return location;
    }
  }
}
