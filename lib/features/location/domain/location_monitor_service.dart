import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' hide Location;
import '../../../core/models/location.dart';
import '../../../core/utils/app_logger.dart';
import '../data/gps_label.dart';
import 'location_repository.dart';

/// GPS karşılaştırması için gereken tek şey koordinat; `Position`'ın kalan
/// alanları kullanılmadığı için karar mantığı geolocator'dan bağımsız tutulur.
typedef Coordinates = ({double latitude, double longitude});

/// Bu mesafeden kısa hareketler şehir değişimi sayılmaz.
const double kSignificantDistanceMeters = 5000;

/// Ard arda gelen fix'lerde en fazla bu sıklıkta güncelleme yapılır.
const Duration kMinLocationUpdateInterval = Duration(minutes: 30);

/// Kullanıcı gerçekten taşındı mı?
///
/// [previous] `null` ise karşılaştıracak referans yok demektir — yalnızca hiç
/// GPS konumu kaydedilmemişken olur, o zaman ilk fix kabul edilir. Uygulama
/// açılışında referans kayıtlı konumdan tohumlandığı için sıradan bir açılış
/// bu yoldan geçmez.
bool isSignificantLocationChange({
  required Coordinates? previous,
  required Coordinates current,
  required DateTime? lastUpdate,
  required DateTime now,
}) {
  if (previous == null) return true;

  if (lastUpdate != null &&
      now.difference(lastUpdate) < kMinLocationUpdateInterval) {
    return false;
  }

  final distance = Geolocator.distanceBetween(
    previous.latitude,
    previous.longitude,
    current.latitude,
    current.longitude,
  );
  return distance >= kSignificantDistanceMeters;
}

class LocationMonitorService {
  final LocationRepository locationRepository;
  final AppLogger logger = AppLogger();

  // GPS konumu tek satır olarak saklanır; saveOrUpdateGpsLocation aynı kaydı
  // günceller, bu yüzden sabit bir kimlik yeterli.
  static const String _gpsLocationId = 'gps';

  StreamSubscription<Position>? _positionStreamSubscription;
  Coordinates? _lastCoordinates;
  DateTime? _lastUpdateTime;

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

      // Referansı kayıtlı konumdan tohumla. Aksi halde açılıştaki ilk fix
      // karşılaştıracak bir şey bulamayıp her zaman "önemli değişim" sayılır;
      // kullanıcı yerinden kımıldamasa bile önbellek yenilenir ve ekran
      // yeniden yüklenir.
      final latitude = gpsLocation.latitude;
      final longitude = gpsLocation.longitude;
      if (latitude != null && longitude != null) {
        _lastCoordinates = (latitude: latitude, longitude: longitude);
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
      final current = (
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!isSignificantLocationChange(
        previous: _lastCoordinates,
        current: current,
        lastUpdate: _lastUpdateTime,
        now: DateTime.now(),
      )) {
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
          _lastCoordinates = current;
          _lastUpdateTime = DateTime.now();
          return;
        }

        final gpsLocation = newLocation.copyWith(
          type: LocationType.gps,
          latitude: position.latitude,
          longitude: position.longitude,
        );

        final saved = await locationRepository.saveOrUpdateGpsLocation(
          gpsLocation,
        );

        _lastCoordinates = current;
        _lastUpdateTime = DateTime.now();

        // Önbellek burada SİLİNMEZ. Dinleyen taraf (HomePage) yüklemeyi
        // `forceRefresh` ile yapar: yeni veri başarıyla gelirse aynı günlerin
        // üzerine yazılır, ağ yoksa eski veri yerinde kalır. Önce silmek, ağ
        // hatasında kullanıcıyı verisiz bırakıyordu.
        _locationChangeController.add(saved);

        logger.debug('GPS location updated: ${saved.displayName}');
      }
    } catch (e) {
      logger.error('Failed to process location change', e);
    }
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

      final label = resolveGpsLabel(placemarks.first);

      // Ham GPS koordinatı doğrudan kullanılır; il/ilçe yalnızca etikettir.
      return Location(
        id: _gpsLocationId,
        province: label.province,
        district: label.district,
        latitude: latitude,
        longitude: longitude,
        type: LocationType.gps,
      );
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
