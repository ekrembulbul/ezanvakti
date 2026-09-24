import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/di/service_locator.dart';
import '../../core/theme/tokens_context.dart';
import '../../core/utils/app_logger.dart';
import '../../features/location/data/gps_location_service.dart';
import '../../features/location/data/places_api.dart';
import '../../features/location/domain/location_migration_service.dart';
import '../../features/location/domain/location_repository.dart';
import '../screens/location_add_screen.dart';
import '../screens/location_migration_screen.dart';
import 'home_page.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _isChecking = true;

  /// Kullanıcı kararı bekleyen eski konum kayıtları; `null` ise ekran yok.
  MigrationReport? _migration;

  @override
  void initState() {
    super.initState();
    _checkInitialSetup();
  }

  Future<void> _checkInitialSetup() async {
    final locationRepository = ServiceLocator().get<LocationRepository>();
    final appState = context.read<AppState>();

    try {
      _migration = await _runMigrationIfNeeded(locationRepository);
      // Aktif konum migrasyonda güncellenmiş olabilir; depodan yeniden okunur.
      final activeLocation = await locationRepository.getActiveLocation();
      if (activeLocation != null) appState.setActiveLocation(activeLocation);
    } catch (e) {
      AppLogger().error('Initial setup failed', e);
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  /// Eşlenmemiş (cityId'siz) kayıt varsa sunucuda eşler. Ağ/sunucu hatası
  /// sessizce ertelenir: bir sonraki açılışta yeniden denenir; eşlenmemiş
  /// aktif konum için ana ekran "doğrula" durumunu gösterir.
  Future<MigrationReport?> _runMigrationIfNeeded(
    LocationRepository repository,
  ) async {
    final saved = await repository.getSavedLocations();
    if (saved.every((location) => location.isMapped)) return null;
    try {
      final report = await ServiceLocator()
          .get<LocationMigrationService>()
          .run();
      return report.needsUserInput ? report : null;
    } catch (e) {
      AppLogger().warning('Location migration deferred', e);
      return null;
    }
  }

  Future<void> _onMigrationFinished() async {
    final active = await ServiceLocator()
        .get<LocationRepository>()
        .getActiveLocation();
    if (!mounted) return;
    context.read<AppState>().setActiveLocation(active);
    setState(() => _migration = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        backgroundColor: context.tokens.backgroundStops.last,
        body: Center(
          child: CircularProgressIndicator(color: context.tokens.accent),
        ),
      );
    }

    final migration = _migration;
    if (migration != null) {
      final locator = ServiceLocator();
      return LocationMigrationScreen(
        report: migration,
        locationRepository: locator.get<LocationRepository>(),
        placesApi: locator.get<PlacesApi>(),
        onFinished: _onMigrationFinished,
      );
    }

    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (appState.hasActiveLocation) {
          return HomePage(key: ValueKey(appState.activeLocation?.id));
        } else {
          final locator = ServiceLocator();
          return LocationAddScreen(
            locationRepository: locator.get<LocationRepository>(),
            placesApi: locator.get<PlacesApi>(),
            gpsService: locator.get<GpsLocationService>(),
          );
        }
      },
    );
  }
}
