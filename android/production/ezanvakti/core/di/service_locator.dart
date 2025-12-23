import 'package:http/http.dart' as http;
import '../../features/prayer_times/data/awqat_salah_provider.dart';
import '../../features/prayer_times/data/sqlite_storage.dart';
import '../../features/prayer_times/domain/prayer_times_repository.dart';
import '../../features/prayer_times/domain/offline_state_manager.dart';
import '../../features/location/domain/location_repository.dart';
import '../../features/location/domain/location_service.dart';
import '../../features/notifications/data/flutter_local_notification_service.dart';
import '../../features/notifications/domain/notification_scheduler.dart';
import '../../features/notifications/domain/notification_settings_manager.dart';
import '../interfaces/prayer_time_provider.dart';
import '../interfaces/local_storage.dart';
import '../interfaces/notification_service.dart';
import '../services/timezone_service.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  final Map<Type, dynamic> _services = {};

  T get<T>() {
    if (!_services.containsKey(T)) {
      throw Exception('Service of type $T not registered');
    }
    return _services[T] as T;
  }

  void register<T>(T service) {
    _services[T] = service;
  }

  bool isRegistered<T>() {
    return _services.containsKey(T);
  }

  Future<void> initialize() async {
    final timezoneService = TimezoneService.instance;
    await timezoneService.initialize();
    register<TimezoneService>(timezoneService);

    final httpClient = http.Client();
    register<http.Client>(httpClient);

    final prayerTimeProvider = AwqatSalahProvider(httpClient: httpClient);
    register<PrayerTimeProvider>(prayerTimeProvider);

    final localStorage = SqliteStorage();
    register<LocalStorage>(localStorage);

    final prayerTimesRepository = PrayerTimesRepository(
      provider: prayerTimeProvider,
      storage: localStorage,
    );
    register<PrayerTimesRepository>(prayerTimesRepository);

    final offlineStateManager = OfflineStateManager(storage: localStorage);
    register<OfflineStateManager>(offlineStateManager);

    final locationRepository = LocationRepository(storage: localStorage);
    register<LocationRepository>(locationRepository);

    final notificationService = FlutterLocalNotificationService();
    await notificationService.init();
    register<NotificationService>(notificationService);

    final locationService = LocationService(
      locationRepository: locationRepository,
      prayerTimesRepository: prayerTimesRepository,
      notificationService: notificationService,
    );
    register<LocationService>(locationService);

    final notificationScheduler = NotificationScheduler(
      notificationService: notificationService,
      storage: localStorage,
    );
    register<NotificationScheduler>(notificationScheduler);

    final notificationSettingsManager = NotificationSettingsManager(
      storage: localStorage,
    );
    register<NotificationSettingsManager>(notificationSettingsManager);
  }

  Future<void> dispose() async {
    final httpClient = get<http.Client>();
    httpClient.close();
    _services.clear();
  }
}
