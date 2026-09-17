import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:geolocator/geolocator.dart';

import '../../../core/models/location.dart';
import '../../../core/utils/app_logger.dart';
import '../data/gps_location_service.dart';
import '../data/places_api.dart';
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

/// Arka planda GPS'i izler; önemli bir yer değişiminde koordinatı sunucuda
/// ilçeye çözer. Vakit ilçeye bağlı olduğu için yalnız `cityId` değişince
/// konum "değişmiş" sayılır: önbellek temizlenir ve [onLocationChanged]
/// yayılır. Aynı ilçe içindeki hareket sessizce koordinatı tazeler (kıble).
class LocationMonitorService {
  final LocationRepository locationRepository;
  final GpsLocationService gps;
  final AppLogger logger = AppLogger();

  StreamSubscription<Position>? _positionStreamSubscription;
  Coordinates? _lastCoordinates;
  DateTime? _lastUpdateTime;

  final _locationChangeController = StreamController<Location>.broadcast();
  Stream<Location> get onLocationChanged => _locationChangeController.stream;

  LocationMonitorService({required this.locationRepository, required this.gps});

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
      // kullanıcı yerinden kımıldamasa bile sunucuya sorulur.
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
            (position) => handleFix((
              latitude: position.latitude,
              longitude: position.longitude,
            )),
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

  /// Bir GPS fix'ini işler. Akıştan çağrılır; testler doğrudan çağırır.
  @visibleForTesting
  Future<void> handleFix(Coordinates current, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    try {
      if (!isSignificantLocationChange(
        previous: _lastCoordinates,
        current: current,
        lastUpdate: _lastUpdateTime,
        now: at,
      )) {
        return;
      }

      // Koordinat log'lanmaz (gizlilik).
      logger.debug('Significant location change detected');

      final existing = await locationRepository.getGpsLocation();
      final GpsResolution resolution;
      try {
        resolution = await gps.resolve(
          current.latitude,
          current.longitude,
          customName: existing?.customName,
        );
      } on NoCoverageException {
        // Türkiye dışı: eski ilçe kalır; bu fix referans olur, tekrar sorulmaz.
        logger.info('GPS fix outside coverage; keeping previous district');
        _lastCoordinates = current;
        _lastUpdateTime = at;
        return;
      } on Exception catch (e) {
        // Ağ yok: referans güncellenmez, bir sonraki fix yeniden dener.
        logger.debug('GPS resolve skipped', e);
        return;
      }

      _lastCoordinates = current;
      _lastUpdateTime = at;

      final saved = await locationRepository.saveOrUpdateGpsLocation(
        resolution.location,
      );
      if (existing != null && existing.cityId == saved.cityId) {
        // Aynı ilçe: koordinat kıble için yazıldı; önbellek ve planlama geçerli.
        final active = await locationRepository.getActiveLocation();
        if (active?.id == saved.id) {
          await locationRepository.setActiveLocation(saved);
        }
        logger.debug('GPS district unchanged, coordinates refreshed');
        return;
      }

      // Repository ilçe değişiminde önbelleği yeni konum yayımlanmadan önce
      // geçersizleştirdi; dinleyici vakitleri yeniden çeker.
      _locationChangeController.add(saved);
      logger.debug('GPS location updated: ${saved.displayName}');
    } catch (e) {
      logger.error('Failed to process location change', e);
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
