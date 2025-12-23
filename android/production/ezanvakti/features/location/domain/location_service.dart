import '../../../core/models/location.dart';
import '../../../core/interfaces/notification_service.dart';
import '../../prayer_times/domain/prayer_times_repository.dart';
import 'location_repository.dart';

class LocationService {
  final LocationRepository locationRepository;
  final PrayerTimesRepository prayerTimesRepository;
  final NotificationService? notificationService;

  LocationService({
    required this.locationRepository,
    required this.prayerTimesRepository,
    this.notificationService,
  });

  Future<Location?> getActiveLocation() async {
    return await locationRepository.getActiveLocation();
  }

  Future<void> changeLocation(Location newLocation) async {
    final oldLocation = await locationRepository.getActiveLocation();

    if (oldLocation?.id == newLocation.id) {
      return;
    }

    await locationRepository.setActiveLocation(newLocation);

    await _updateCacheForNewLocation(newLocation);

    if (notificationService != null) {
      await _rescheduleNotifications(oldLocation, newLocation);
    }
  }

  Future<void> _updateCacheForNewLocation(Location location) async {
    try {
      await prayerTimesRepository.refreshPrayerTimes(location);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _rescheduleNotifications(
    Location? oldLocation,
    Location newLocation,
  ) async {
    if (notificationService == null) return;

    await notificationService!.cancelAllNotifications();
  }

  List<String> getAllProvinces() {
    return locationRepository.getAllProvinces();
  }

  List<Location> getDistrictsByProvince(String province) {
    return locationRepository.getDistrictsByProvince(province);
  }

  Location? getLocationById(String id) {
    return locationRepository.getLocationById(id);
  }

  List<Location> searchLocations(String query) {
    return locationRepository.searchLocations(query);
  }
}
