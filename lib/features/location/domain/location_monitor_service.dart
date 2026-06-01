import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' hide Location;
import '../../../core/models/location.dart';
import '../../../core/utils/app_logger.dart';
import '../data/turkey_locations_data.dart';
import 'location_repository.dart';

class LocationMonitorService {
  final LocationRepository locationRepository;
  final AppLogger logger = AppLogger();

  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _lastPosition;
  DateTime? _lastUpdateTime;

  static const double _significantDistanceMeters = 5000; // 5km
  static const Duration _minUpdateInterval = Duration(minutes: 30);

  final _locationChangeController = StreamController<Location>.broadcast();
  Stream<Location> get onLocationChanged => _locationChangeController.stream;

  LocationMonitorService({required this.locationRepository});

  Future<void> startMonitoring() async {
    logger.debug('Starting GPS location monitoring');

    try {
      final hasPermission = await _checkPermissions();
      if (!hasPermission) {
        logger.warning('Location permission not granted, monitoring disabled');
        return;
      }

      final gpsLocation = await locationRepository.getGpsLocation();
      if (gpsLocation == null) {
        logger.debug('No GPS location saved, monitoring disabled');
        return;
      }

      _positionStreamSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              distanceFilter: 1000, // Update every 1km movement
            ),
          ).listen(
            _onPositionChanged,
            onError: (error) {
              logger.error('Location stream error', error);
            },
          );

      logger.debug('GPS location monitoring started');
    } catch (e) {
      logger.error('Failed to start location monitoring', e);
    }
  }

  Future<bool> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> _onPositionChanged(Position position) async {
    try {
      if (!_shouldUpdate(position)) {
        return;
      }

      // Note: GPS coordinates are intentionally not logged (privacy).
      logger.debug('Significant location change detected');

      final newLocation = await _getLocationFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (newLocation != null) {
        final existingGpsLocation = await locationRepository.getGpsLocation();

        if (existingGpsLocation != null &&
            existingGpsLocation.province == newLocation.province &&
            existingGpsLocation.district == newLocation.district) {
          logger.debug('GPS location unchanged, skipping update');
          _lastPosition = position;
          _lastUpdateTime = DateTime.now();
          return;
        }

        final gpsLocation = newLocation.copyWith(
          type: LocationType.gps,
          latitude: position.latitude,
          longitude: position.longitude,
        );

        await locationRepository.saveOrUpdateGpsLocation(gpsLocation);

        _lastPosition = position;
        _lastUpdateTime = DateTime.now();

        _locationChangeController.add(gpsLocation);

        logger.debug('GPS location updated: ${gpsLocation.displayName}');
      }
    } catch (e) {
      logger.error('Failed to process location change', e);
    }
  }

  bool _shouldUpdate(Position position) {
    if (_lastPosition == null) {
      return true;
    }

    if (_lastUpdateTime != null) {
      final timeSinceLastUpdate = DateTime.now().difference(_lastUpdateTime!);
      if (timeSinceLastUpdate < _minUpdateInterval) {
        return false;
      }
    }

    final distance = Geolocator.distanceBetween(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    return distance >= _significantDistanceMeters;
  }

  Future<Location?> _getLocationFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty) return null;

      final placemark = placemarks.first;
      final province = placemark.administrativeArea ?? '';
      final district =
          placemark.subAdministrativeArea ?? placemark.locality ?? '';

      if (province.isEmpty || district.isEmpty) return null;

      return TurkeyLocationsData.findMatchingLocation(province, district);
    } catch (e) {
      logger.error('Reverse geocoding failed', e);
      return null;
    }
  }

  void stopMonitoring() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    logger.debug('GPS location monitoring stopped');
  }

  void dispose() {
    stopMonitoring();
    _locationChangeController.close();
  }
}
