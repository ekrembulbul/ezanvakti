import 'dart:async';

import '../../core/models/location.dart';
import '../../features/location/domain/location_monitor_service.dart';
import '../../features/location/domain/location_repository.dart';
import '../../core/utils/app_logger.dart';

class LocationMonitorController {
  final LocationMonitorService _monitorService;
  final LocationRepository _locationRepository;
  final AppLogger _logger;
  final Function(Location) _onLocationChanged;

  StreamSubscription<Location>? _locationSubscription;

  LocationMonitorController({
    required LocationMonitorService monitorService,
    required LocationRepository locationRepository,
    required AppLogger logger,
    required Function(Location) onLocationChanged,
  }) : _monitorService = monitorService,
       _locationRepository = locationRepository,
       _logger = logger,
       _onLocationChanged = onLocationChanged;

  Future<void> startMonitoring(Location? activeLocation) async {
    if (activeLocation?.type != LocationType.gps) return;

    // Avoid stacking subscriptions if monitoring is started more than once.
    await _locationSubscription?.cancel();
    _locationSubscription = _monitorService.onLocationChanged.listen((
      newLocation,
    ) async {
      _logger.debug('GPS location changed, refreshing prayer times');
      await _locationRepository.setActiveLocation(newLocation);
      _onLocationChanged(newLocation);
    });

    await _monitorService.startMonitoring();
  }

  Future<void> stopMonitoring() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _monitorService.stopMonitoring();
  }
}
