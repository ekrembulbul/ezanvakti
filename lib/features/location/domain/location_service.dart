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

    final sameLocation = oldLocation?.id == newLocation.id;
    final calcParamsChanged =
        oldLocation != null && _calcParamsChanged(oldLocation, newLocation);

    // Konum ve hesaplama parametreleri aynıysa yapılacak iş yok.
    if (sameLocation && !calcParamsChanged) {
      return;
    }

    // Aynı konum ama farklı method/school: önbellekteki vakitler geçersizdir.
    if (sameLocation && calcParamsChanged) {
      await prayerTimesRepository.clearCacheForLocation(newLocation.id);
    }

    await locationRepository.setActiveLocation(newLocation);

    await _updateCacheForNewLocation(newLocation);

    if (notificationService != null) {
      await _rescheduleNotifications(oldLocation, newLocation);
    }
  }

  bool _calcParamsChanged(Location a, Location b) {
    return a.method != b.method ||
        a.school != b.school ||
        a.latitudeAdjustmentMethod != b.latitudeAdjustmentMethod;
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
}
