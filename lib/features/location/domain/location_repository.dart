import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/location.dart';
import '../../../core/models/calculation_settings.dart';

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

  /// Bir konumun önbellekteki vakitlerini siler. Yeni bir konum eklenirken veya
  /// hesaplama parametreleri değişirken çağrılır; bir sonraki yükleme güncel
  /// parametrelerle yeniden çeker.
  Future<void> clearPrayerTimeCache(String locationId) async {
    await storage.deletePrayerTimesForLocation(locationId);
  }

  /// Uygulama genelindeki varsayılan hesaplama ayarını döner. Konum düzenleme
  /// ekranı "genel ayarı kullan" durumunda etkin değerleri göstermek için kullanır.
  Future<CalculationSettings> getCalculationSettings() async {
    return await storage.getCalculationSettings();
  }

  /// Uygulama genelindeki varsayılan hesaplama ayarını kaydeder. İlk konum
  /// eklenirken bölgesel varsayılanı atamak için kullanılır.
  Future<void> saveCalculationSettings(CalculationSettings settings) async {
    await storage.saveCalculationSettings(settings);
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
}
