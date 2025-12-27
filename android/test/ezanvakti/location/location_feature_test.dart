import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/interfaces/notification_service.dart';
import 'package:ezanvakti/core/interfaces/prayer_time_provider.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/features/location/data/turkey_locations_data.dart';
import 'package:ezanvakti/features/location/domain/location_repository.dart';
import 'package:ezanvakti/features/location/domain/location_service.dart';
import 'package:ezanvakti/features/prayer_times/domain/prayer_times_repository.dart';

class MockLocalStorage implements LocalStorage {
  final Map<String, List<PrayerTime>> _prayerTimesCache = {};
  Location? _activeLocation;
  List<NotificationSetting> _notificationSettings = [];
  DateTime? _lastUpdateTime;

  @override
  Future<void> init() async {}

  @override
  Future<void> savePrayerTimes(
    List<PrayerTime> prayerTimes,
    String locationId,
  ) async {
    if (!_prayerTimesCache.containsKey(locationId)) {
      _prayerTimesCache[locationId] = [];
    }

    for (final newTime in prayerTimes) {
      _prayerTimesCache[locationId]!.removeWhere(
        (pt) =>
            pt.date.year == newTime.date.year &&
            pt.date.month == newTime.date.month &&
            pt.date.day == newTime.date.day,
      );
      _prayerTimesCache[locationId]!.add(newTime);
    }

    _prayerTimesCache[locationId]!.sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<List<PrayerTime>> getPrayerTimes({
    required String locationId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final times = _prayerTimesCache[locationId] ?? [];
    final normalizedStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);

    return times.where((pt) {
      final normalizedDate = DateTime(pt.date.year, pt.date.month, pt.date.day);
      return (normalizedDate.isAtSameMomentAs(normalizedStart) ||
              normalizedDate.isAfter(normalizedStart)) &&
          (normalizedDate.isAtSameMomentAs(normalizedEnd) ||
              normalizedDate.isBefore(normalizedEnd));
    }).toList();
  }

  @override
  Future<PrayerTime?> getDailyPrayerTime({
    required String locationId,
    required DateTime date,
  }) async {
    final times = _prayerTimesCache[locationId] ?? [];
    try {
      return times.firstWhere(
        (pt) =>
            pt.date.year == date.year &&
            pt.date.month == date.month &&
            pt.date.day == date.day,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteOldPrayerTimes(DateTime cutoffDate) async {
    for (var key in _prayerTimesCache.keys) {
      _prayerTimesCache[key] = _prayerTimesCache[key]!
          .where(
            (pt) =>
                pt.date.isAfter(cutoffDate) ||
                pt.date.isAtSameMomentAs(cutoffDate),
          )
          .toList();
    }
  }

  @override
  Future<void> saveActiveLocation(Location location) async {
    _activeLocation = location;
  }

  @override
  Future<Location?> getActiveLocation() async {
    return _activeLocation;
  }

  @override
  Future<void> saveNotificationSettings(
    List<NotificationSetting> settings,
  ) async {
    _notificationSettings = settings;
  }

  @override
  Future<List<NotificationSetting>> getNotificationSettings() async {
    return _notificationSettings;
  }

  @override
  Future<void> saveLastUpdateTime(DateTime time) async {
    _lastUpdateTime = time;
  }

  @override
  Future<DateTime?> getLastUpdateTime() async {
    return _lastUpdateTime;
  }

  Map<String, List<PrayerTime>> get cacheForTesting => _prayerTimesCache;
}

class MockPrayerTimeProvider implements PrayerTimeProvider {
  int fetchCallCount = 0;
  bool shouldThrowError = false;

  @override
  String get providerName => 'Mock Provider';

  @override
  Future<List<PrayerTime>> fetchPrayerTimes({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    fetchCallCount++;

    if (shouldThrowError) {
      throw Exception('Network error');
    }

    final List<PrayerTime> times = [];
    DateTime currentDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);

    while (currentDate.isBefore(normalizedEnd.add(const Duration(days: 1)))) {
      times.add(
        PrayerTime(
          fajr: DateTime(
            currentDate.year,
            currentDate.month,
            currentDate.day,
            5,
            30,
          ),
          sunrise: DateTime(
            currentDate.year,
            currentDate.month,
            currentDate.day,
            7,
            0,
          ),
          dhuhr: DateTime(
            currentDate.year,
            currentDate.month,
            currentDate.day,
            13,
            15,
          ),
          asr: DateTime(
            currentDate.year,
            currentDate.month,
            currentDate.day,
            16,
            30,
          ),
          maghrib: DateTime(
            currentDate.year,
            currentDate.month,
            currentDate.day,
            19,
            0,
          ),
          isha: DateTime(
            currentDate.year,
            currentDate.month,
            currentDate.day,
            20,
            30,
          ),
          date: currentDate,
        ),
      );
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return times;
  }

  @override
  Future<PrayerTime?> fetchDailyPrayerTime({
    required Location location,
    required DateTime date,
  }) async {
    fetchCallCount++;

    if (shouldThrowError) {
      throw Exception('Network error');
    }

    final normalizedDate = DateTime(date.year, date.month, date.day);
    return PrayerTime(
      fajr: DateTime(
        normalizedDate.year,
        normalizedDate.month,
        normalizedDate.day,
        5,
        30,
      ),
      sunrise: DateTime(
        normalizedDate.year,
        normalizedDate.month,
        normalizedDate.day,
        7,
        0,
      ),
      dhuhr: DateTime(
        normalizedDate.year,
        normalizedDate.month,
        normalizedDate.day,
        13,
        15,
      ),
      asr: DateTime(
        normalizedDate.year,
        normalizedDate.month,
        normalizedDate.day,
        16,
        30,
      ),
      maghrib: DateTime(
        normalizedDate.year,
        normalizedDate.month,
        normalizedDate.day,
        19,
        0,
      ),
      isha: DateTime(
        normalizedDate.year,
        normalizedDate.month,
        normalizedDate.day,
        20,
        30,
      ),
      date: normalizedDate,
    );
  }
}

class MockNotificationService implements NotificationService {
  bool _permissionGranted = false;
  final Map<String, ScheduledNotification> _scheduledNotifications = {};
  int cancelAllCallCount = 0;
  @override
  Future<void> openExactAlarmSettings() async {}

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async {
    _permissionGranted = true;
    return true;
  }

  @override
  Future<bool> isPermissionGranted() async {
    return _permissionGranted;
  }

  @override
  Future<void> scheduleNotification({
    required String id,
    required DateTime scheduledTime,
    required String title,
    required String body,
  }) async {
    _scheduledNotifications[id] = ScheduledNotification(
      id: id,
      scheduledTime: scheduledTime,
      prayerType: PrayerType.fajr,
      minutesBefore: 0,
    );
  }

  @override
  Future<void> cancelNotification(String id) async {
    _scheduledNotifications.remove(id);
  }

  @override
  Future<void> cancelAllNotifications() async {
    cancelAllCallCount++;
    _scheduledNotifications.clear();
  }

  @override
  Future<List<ScheduledNotification>> getPendingNotifications() async {
    return _scheduledNotifications.values.toList();
  }
}

void main() {
  group('Location Feature - Turkey Locations Data', () {
    test('Turkey locations data contains valid locations', () {
      final locations = TurkeyLocationsData.getAllLocations();

      expect(locations, isNotEmpty);
      expect(locations.first, isA<Location>());
      expect(locations.first.latitude, isNotNull);
      expect(locations.first.longitude, isNotNull);
    });

    test('Can get all provinces', () {
      final provinces = TurkeyLocationsData.getAllProvinces();

      expect(provinces, isNotEmpty);
      expect(provinces, contains('İstanbul'));
      expect(provinces, contains('Ankara'));
      expect(provinces, contains('İzmir'));
    });

    test('Provinces are sorted alphabetically', () {
      final provinces = TurkeyLocationsData.getAllProvinces();

      final sortedProvinces = List<String>.from(provinces)..sort();
      expect(provinces, equals(sortedProvinces));
    });

    test('Can get districts by province', () {
      final istanbulDistricts = TurkeyLocationsData.getDistrictsByProvince(
        'İstanbul',
      );

      expect(istanbulDistricts, isNotEmpty);
      expect(
        istanbulDistricts.every((loc) => loc.province == 'İstanbul'),
        isTrue,
      );
    });

    test('Districts are sorted alphabetically', () {
      final districts = TurkeyLocationsData.getDistrictsByProvince('İstanbul');

      final districtNames = districts.map((d) => d.district).toList();
      final sortedNames = List<String>.from(districtNames)..sort();
      expect(districtNames, equals(sortedNames));
    });

    test('Can get location by ID', () {
      final location = TurkeyLocationsData.getLocationById('9635');

      expect(location, isNotNull);
      expect(location!.province, equals('İstanbul'));
      expect(location.district, equals('Kadıköy'));
    });

    test('Returns null for invalid location ID', () {
      final location = TurkeyLocationsData.getLocationById('invalid_id');

      expect(location, isNull);
    });

    test('Can search locations by province name', () {
      final results = TurkeyLocationsData.searchLocations('İstanbul');

      expect(results, isNotEmpty);
      expect(results.every((loc) => loc.province == 'İstanbul'), isTrue);
    });

    test('Can search locations by district name', () {
      final results = TurkeyLocationsData.searchLocations('Kadıköy');

      expect(results, isNotEmpty);
      expect(results.any((loc) => loc.district == 'Kadıköy'), isTrue);
    });

    test('Search is case-insensitive', () {
      final results1 = TurkeyLocationsData.searchLocations('istanbul');
      final results2 = TurkeyLocationsData.searchLocations('İSTANBUL');

      expect(results1, isNotEmpty);
      expect(results2, isNotEmpty);
    });

    test('Empty search query returns empty list', () {
      final results = TurkeyLocationsData.searchLocations('');

      expect(results, isEmpty);
    });
  });

  group('Location Feature - Location Repository', () {
    late MockLocalStorage storage;
    late LocationRepository repository;

    setUp(() {
      storage = MockLocalStorage();
      repository = LocationRepository(storage: storage);
    });

    test('Repository can save and retrieve active location', () async {
      const location = Location(
        id: '9635',
        province: 'İstanbul',
        district: 'Kadıköy',
        latitude: 40.9828,
        longitude: 29.0227,
      );

      await repository.setActiveLocation(location);
      final retrieved = await repository.getActiveLocation();

      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('9635'));
      expect(retrieved.province, equals('İstanbul'));
      expect(retrieved.district, equals('Kadıköy'));
    });

    test('Repository returns null when no active location is set', () async {
      final location = await repository.getActiveLocation();

      expect(location, isNull);
    });

    test('Repository can get all provinces', () {
      final provinces = repository.getAllProvinces();

      expect(provinces, isNotEmpty);
      expect(provinces, contains('İstanbul'));
    });

    test('Repository can get districts by province', () {
      final districts = repository.getDistrictsByProvince('Ankara');

      expect(districts, isNotEmpty);
      expect(districts.every((d) => d.province == 'Ankara'), isTrue);
    });

    test('Repository can get location by ID', () {
      final location = repository.getLocationById('9206');

      expect(location, isNotNull);
      expect(location!.province, equals('Ankara'));
    });

    test('Repository can search locations', () {
      final results = repository.searchLocations('Bursa');

      expect(results, isNotEmpty);
      expect(results.every((loc) => loc.province == 'Bursa'), isTrue);
    });
  });

  group('Location Feature - Location Service with Cache Update', () {
    late MockLocalStorage storage;
    late MockPrayerTimeProvider provider;
    late MockNotificationService notificationService;
    late LocationRepository locationRepository;
    late PrayerTimesRepository prayerTimesRepository;
    late LocationService locationService;

    setUp(() {
      storage = MockLocalStorage();
      provider = MockPrayerTimeProvider();
      notificationService = MockNotificationService();
      locationRepository = LocationRepository(storage: storage);
      prayerTimesRepository = PrayerTimesRepository(
        provider: provider,
        storage: storage,
      );
      locationService = LocationService(
        locationRepository: locationRepository,
        prayerTimesRepository: prayerTimesRepository,
        notificationService: notificationService,
      );
    });

    test('Location service can get active location', () async {
      const location = Location(
        id: '9635',
        province: 'İstanbul',
        district: 'Kadıköy',
        latitude: 40.9828,
        longitude: 29.0227,
      );

      await locationRepository.setActiveLocation(location);
      final retrieved = await locationService.getActiveLocation();

      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('9635'));
    });

    test('Changing location updates cache with new prayer times', () async {
      const location1 = Location(
        id: '9635',
        province: 'İstanbul',
        district: 'Kadıköy',
        latitude: 40.9828,
        longitude: 29.0227,
      );

      const location2 = Location(
        id: '9206',
        province: 'Ankara',
        district: 'Çankaya',
        latitude: 39.9167,
        longitude: 32.8667,
      );

      await locationService.changeLocation(location1);

      expect(storage.cacheForTesting.containsKey(location1.id), isTrue);
      expect(storage.cacheForTesting[location1.id], isNotEmpty);

      await locationService.changeLocation(location2);

      expect(storage.cacheForTesting.containsKey(location2.id), isTrue);
      expect(storage.cacheForTesting[location2.id], isNotEmpty);
    });

    test('Changing location cancels all notifications', () async {
      const location1 = Location(
        id: '9635',
        province: 'İstanbul',
        district: 'Kadıköy',
        latitude: 40.9828,
        longitude: 29.0227,
      );

      const location2 = Location(
        id: '9206',
        province: 'Ankara',
        district: 'Çankaya',
        latitude: 39.9167,
        longitude: 32.8667,
      );

      await notificationService.scheduleNotification(
        id: 'test_notification',
        scheduledTime: DateTime.now().add(const Duration(hours: 1)),
        title: 'Test',
        body: 'Test',
      );

      expect(notificationService.cancelAllCallCount, equals(0));

      await locationService.changeLocation(location1);

      expect(notificationService.cancelAllCallCount, equals(1));

      await locationService.changeLocation(location2);

      expect(notificationService.cancelAllCallCount, equals(2));
    });

    test('Changing to same location does not trigger updates', () async {
      const location = Location(
        id: '9635',
        province: 'İstanbul',
        district: 'Kadıköy',
        latitude: 40.9828,
        longitude: 29.0227,
      );

      await locationService.changeLocation(location);

      provider.fetchCallCount = 0;
      notificationService.cancelAllCallCount = 0;

      await locationService.changeLocation(location);

      expect(provider.fetchCallCount, equals(0));
      expect(notificationService.cancelAllCallCount, equals(0));
    });

    test(
      'Location service without notification service works correctly',
      () async {
        final serviceWithoutNotifications = LocationService(
          locationRepository: locationRepository,
          prayerTimesRepository: prayerTimesRepository,
        );

        const location = Location(
          id: '9635',
          province: 'İstanbul',
          district: 'Kadıköy',
          latitude: 40.9828,
          longitude: 29.0227,
        );

        await expectLater(
          serviceWithoutNotifications.changeLocation(location),
          completes,
        );
      },
    );

    test('Location change fetches 30 days of prayer times', () async {
      const location = Location(
        id: '9635',
        province: 'İstanbul',
        district: 'Kadıköy',
        latitude: 40.9828,
        longitude: 29.0227,
      );

      await locationService.changeLocation(location);

      final cached = storage.cacheForTesting[location.id]!;
      expect(cached.length, greaterThanOrEqualTo(30));
    });

    test('Location service can search locations', () {
      final results = locationService.searchLocations('Antalya');

      expect(results, isNotEmpty);
      expect(results.every((loc) => loc.province == 'Antalya'), isTrue);
    });

    test('Location service can get provinces', () {
      final provinces = locationService.getAllProvinces();

      expect(provinces, isNotEmpty);
      expect(provinces, contains('İzmir'));
    });

    test('Location service can get districts by province', () {
      final districts = locationService.getDistrictsByProvince('Konya');

      expect(districts, isNotEmpty);
      expect(districts.every((d) => d.province == 'Konya'), isTrue);
    });

    test('Location service can get location by ID', () {
      final location = locationService.getLocationById('9045');

      expect(location, isNotNull);
      expect(location!.province, equals('Adana'));
    });
  });

  group('Location Feature - Cache Update on Location Change', () {
    late MockLocalStorage storage;
    late MockPrayerTimeProvider provider;
    late LocationRepository locationRepository;
    late PrayerTimesRepository prayerTimesRepository;
    late LocationService locationService;

    setUp(() {
      storage = MockLocalStorage();
      provider = MockPrayerTimeProvider();
      locationRepository = LocationRepository(storage: storage);
      prayerTimesRepository = PrayerTimesRepository(
        provider: provider,
        storage: storage,
      );
      locationService = LocationService(
        locationRepository: locationRepository,
        prayerTimesRepository: prayerTimesRepository,
      );
    });

    test('Old location cache remains after location change', () async {
      const location1 = Location(
        id: '9635',
        province: 'İstanbul',
        district: 'Kadıköy',
        latitude: 40.9828,
        longitude: 29.0227,
      );

      const location2 = Location(
        id: '9206',
        province: 'Ankara',
        district: 'Çankaya',
        latitude: 39.9167,
        longitude: 32.8667,
      );

      await locationService.changeLocation(location1);
      await locationService.changeLocation(location2);

      expect(storage.cacheForTesting.containsKey(location1.id), isTrue);
      expect(storage.cacheForTesting.containsKey(location2.id), isTrue);
    });

    test('Active location is correctly updated after change', () async {
      const location1 = Location(
        id: '9635',
        province: 'İstanbul',
        district: 'Kadıköy',
        latitude: 40.9828,
        longitude: 29.0227,
      );

      const location2 = Location(
        id: '9206',
        province: 'Ankara',
        district: 'Çankaya',
        latitude: 39.9167,
        longitude: 32.8667,
      );

      await locationService.changeLocation(location1);
      var active = await locationService.getActiveLocation();
      expect(active!.id, equals(location1.id));

      await locationService.changeLocation(location2);
      active = await locationService.getActiveLocation();
      expect(active!.id, equals(location2.id));
    });

    test('Location change fetches 30 days of prayer times', () async {
      const location = Location(
        id: '9635',
        province: 'İstanbul',
        district: 'Kadıköy',
        latitude: 40.9828,
        longitude: 29.0227,
      );

      await locationService.changeLocation(location);

      final cached = storage.cacheForTesting[location.id]!;
      expect(cached.length, greaterThanOrEqualTo(30));
    });

    test('Location service can search locations', () {
      final results = locationService.searchLocations('Antalya');

      expect(results, isNotEmpty);
      expect(results.every((loc) => loc.province == 'Antalya'), isTrue);
    });

    test('Location service can get provinces', () {
      final provinces = locationService.getAllProvinces();

      expect(provinces, isNotEmpty);
      expect(provinces, contains('İzmir'));
    });

    test('Location service can get districts by province', () {
      final districts = locationService.getDistrictsByProvince('Konya');

      expect(districts, isNotEmpty);
      expect(districts.every((d) => d.province == 'Konya'), isTrue);
    });

    test('Location service can get location by ID', () {
      final location = locationService.getLocationById('9045');

      expect(location, isNotNull);
      expect(location!.province, equals('Adana'));
    });
  });

  group('Location Feature - Cache Update on Location Change', () {
    late MockLocalStorage storage;
    late MockPrayerTimeProvider provider;
    late LocationRepository locationRepository;
    late PrayerTimesRepository prayerTimesRepository;
    late LocationService locationService;

    setUp(() {
      storage = MockLocalStorage();
      provider = MockPrayerTimeProvider();
      locationRepository = LocationRepository(storage: storage);
      prayerTimesRepository = PrayerTimesRepository(
        provider: provider,
        storage: storage,
      );
      locationService = LocationService(
        locationRepository: locationRepository,
        prayerTimesRepository: prayerTimesRepository,
      );
    });

    test('Old location cache remains after location change', () async {
      const location1 = Location(
        id: '9635',
        province: 'İstanbul',
        district: 'Kadıköy',
        latitude: 40.9828,
        longitude: 29.0227,
      );

      const location2 = Location(
        id: '9206',
        province: 'Ankara',
        district: 'Çankaya',
        latitude: 39.9167,
        longitude: 32.8667,
      );

      await locationService.changeLocation(location1);
      await locationService.changeLocation(location2);

      expect(storage.cacheForTesting.containsKey(location1.id), isTrue);
      expect(storage.cacheForTesting.containsKey(location2.id), isTrue);
    });

    test('Multiple location changes are handled correctly', () async {
      const location1 = Location(
        id: '9635',
        province: 'İstanbul',
        district: 'Kadıköy',
        latitude: 40.9828,
        longitude: 29.0227,
      );

      const location2 = Location(
        id: '9206',
        province: 'Ankara',
        district: 'Çankaya',
        latitude: 39.9167,
        longitude: 32.8667,
      );

      const location3 = Location(
        id: '9562',
        province: 'İzmir',
        district: 'Bornova',
        latitude: 38.4667,
        longitude: 27.2167,
      );

      await locationService.changeLocation(location1);
      await locationService.changeLocation(location2);
      await locationService.changeLocation(location3);

      final active = await locationService.getActiveLocation();
      expect(active!.id, equals(location3.id));

      expect(storage.cacheForTesting.containsKey(location1.id), isTrue);
      expect(storage.cacheForTesting.containsKey(location2.id), isTrue);
      expect(storage.cacheForTesting.containsKey(location3.id), isTrue);
    });
  });
}
