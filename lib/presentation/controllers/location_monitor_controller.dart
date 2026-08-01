import 'dart:async';

import '../../core/models/location.dart';
import '../../core/utils/app_logger.dart';
import '../../features/location/domain/location_monitor_service.dart';
import '../../features/location/domain/location_service.dart';

class LocationMonitorController {
  final LocationMonitorService _monitorService;
  final LocationService _locationService;
  final AppLogger _logger;
  final Function(Location) _onLocationChanged;

  StreamSubscription<Location>? _locationSubscription;

  LocationMonitorController({
    required LocationMonitorService monitorService,
    required LocationService locationService,
    required AppLogger logger,
    required Function(Location) onLocationChanged,
  }) : _monitorService = monitorService,
       _locationService = locationService,
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
      // Tek kanonik yol: aktif konumu ayarlama, hesaplama parametresi degisince
      // onbellek gecersizlestirme ve eski konumun bildirimlerini iptal etme
      // domain LocationService'e delege edilir — manuel konum degisimiyle ayni
      // davranis. Vakit verisini yeniden yuklemek cagirana (HomePage) aittir.
      await _locationService.changeLocation(newLocation);
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
