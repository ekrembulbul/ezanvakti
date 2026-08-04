import 'dart:async';

import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/utils/app_logger.dart';
import 'package:ezanvakti/features/location/domain/location_monitor_service.dart';
import 'package:ezanvakti/features/location/domain/location_service.dart';
import 'package:ezanvakti/presentation/controllers/location_monitor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// GPS akisini elle tetikleyebilmek icin sahte izleme servisi.
class _FakeMonitorService implements LocationMonitorService {
  final _controller = StreamController<Location>.broadcast();
  bool started = false;

  @override
  Stream<Location> get onLocationChanged => _controller.stream;

  @override
  Future<void> startMonitoring() async => started = true;

  @override
  void stopMonitoring() => started = false;

  @override
  void dispose() => _controller.close();

  void emit(Location location) => _controller.add(location);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// changeLocation cagrilarini kaydeden casus.
class _SpyLocationService implements LocationService {
  final List<Location> changed = [];

  @override
  Future<void> changeLocation(Location newLocation) async {
    changed.add(newLocation);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const gpsLocation = Location(
    id: 'gps',
    province: 'İstanbul',
    district: 'Kadıköy',
    type: LocationType.gps,
  );
  const movedLocation = Location(
    id: 'gps',
    province: 'Ankara',
    district: 'Çankaya',
    type: LocationType.gps,
  );

  test(
    'GPS konum degisimi LocationService.changeLocation uzerinden gider',
    () async {
      final monitor = _FakeMonitorService();
      final service = _SpyLocationService();
      final seen = <Location>[];

      final controller = LocationMonitorController(
        monitorService: monitor,
        locationService: service,
        logger: AppLogger(),
        onLocationChanged: seen.add,
      );

      await controller.startMonitoring(gpsLocation);
      monitor.emit(movedLocation);
      await Future<void>.delayed(Duration.zero);

      expect(service.changed, [movedLocation]);
      expect(seen, [movedLocation]);

      await controller.stopMonitoring();
    },
  );

  test('GPS olmayan aktif konumda izleme baslatilmaz', () async {
    final monitor = _FakeMonitorService();
    final service = _SpyLocationService();

    final controller = LocationMonitorController(
      monitorService: monitor,
      locationService: service,
      logger: AppLogger(),
      onLocationChanged: (_) {},
    );

    await controller.startMonitoring(
      const Location(id: '1', province: 'İstanbul', district: 'Kadıköy'),
    );

    expect(monitor.started, isFalse);
    expect(service.changed, isEmpty);
  });

  test('Ikinci kez baslatmak abonelik yigmaz', () async {
    final monitor = _FakeMonitorService();
    final service = _SpyLocationService();
    final seen = <Location>[];

    final controller = LocationMonitorController(
      monitorService: monitor,
      locationService: service,
      logger: AppLogger(),
      onLocationChanged: seen.add,
    );

    await controller.startMonitoring(gpsLocation);
    await controller.startMonitoring(gpsLocation);
    monitor.emit(movedLocation);
    await Future<void>.delayed(Duration.zero);

    expect(seen, [movedLocation]);

    await controller.stopMonitoring();
  });
}
