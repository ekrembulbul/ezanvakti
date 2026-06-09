import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/calculation_settings.dart';
import 'package:ezanvakti/core/interfaces/prayer_time_provider.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/errors/prayer_times_errors.dart';
import 'package:ezanvakti/features/prayer_times/domain/prayer_times_repository.dart';
import 'package:ezanvakti/features/prayer_times/domain/offline_state_manager.dart';

class MockLocalStorage implements LocalStorage {
  final Map<String, List<PrayerTime>> _prayerTimesCache = {};
  Location? _activeLocation;
  final List<Location> _savedLocations = [];
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
  Future<void> deletePrayerTimesForLocation(String locationId) async {
    _prayerTimesCache.remove(locationId);
  }

  @override
  Future<void> deleteAllPrayerTimes() async {
    _prayerTimesCache.clear();
  }

  CalculationSettings _calculationSettings = CalculationSettings.defaults;

  @override
  Future<CalculationSettings> getCalculationSettings() async =>
      _calculationSettings;

  @override
  Future<void> saveCalculationSettings(CalculationSettings settings) async {
    _calculationSettings = settings;
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
  Future<List<Location>> getSavedLocations() async =>
      List.unmodifiable(_savedLocations);

  @override
  Future<void> saveLocation(Location location) async {
    _savedLocations.removeWhere((l) => l.id == location.id);
    _savedLocations.add(location);
  }

  @override
  Future<void> updateLocation(Location location) async {
    final index = _savedLocations.indexWhere((l) => l.id == location.id);
    if (index >= 0) _savedLocations[index] = location;
  }

  @override
  Future<void> deleteLocation(String locationId) async {
    _savedLocations.removeWhere((l) => l.id == locationId);
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
  Future<void> addNotificationSetting(NotificationSetting setting) async {
    _notificationSettings = [
      ..._notificationSettings.where(
        (s) =>
            !(s.prayerType == setting.prayerType &&
                s.minutesBefore == setting.minutesBefore),
      ),
      setting,
    ];
  }

  @override
  Future<void> deleteNotificationSetting({
    required PrayerType prayerType,
    required int minutesBefore,
  }) async {
    _notificationSettings = _notificationSettings
        .where(
          (s) =>
              !(s.prayerType == prayerType && s.minutesBefore == minutesBefore),
        )
        .toList();
  }

  bool _notificationDefaultsInitialized = false;

  @override
  Future<bool> isNotificationDefaultsInitialized() async {
    return _notificationDefaultsInitialized;
  }

  @override
  Future<void> markNotificationDefaultsInitialized() async {
    _notificationDefaultsInitialized = true;
  }

  @override
  Future<void> saveLastUpdateTime(DateTime time) async {
    _lastUpdateTime = time;
  }

  @override
  Future<DateTime?> getLastUpdateTime() async {
    return _lastUpdateTime;
  }

  final List<Alarm> _alarms = [];
  @override
  Future<List<Alarm>> getAlarms() async => List.from(_alarms);
  @override
  Future<void> saveAlarm(Alarm alarm) async {
    _alarms.removeWhere((a) => a.id == alarm.id);
    _alarms.add(alarm);
  }
  @override
  Future<void> deleteAlarm(String id) async {
    _alarms.removeWhere((a) => a.id == id);
  }

  void clearCache() {
    _prayerTimesCache.clear();
    _lastUpdateTime = null;
  }
}

class MockPrayerTimeProvider implements PrayerTimeProvider {
  bool shouldThrowError = false;
  int fetchCallCount = 0;

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
      throw NetworkException('Simulated network error');
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
      throw NetworkException('Simulated network error');
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

void main() {
  group('Offline Behavior - Error Types', () {
    test('NetworkException has correct message', () {
      final error = NetworkException();
      expect(error.message, equals('Network error occurred'));
      expect(error, isA<PrayerTimesException>());
    });

    test('CacheNotFoundException has correct message', () {
      final error = CacheNotFoundException();
      expect(error.message, equals('No cached data available'));
    });

    test('CacheExpiredException includes details', () {
      final lastUpdate = DateTime(2024, 1, 1);
      final staleDuration = const Duration(days: 7);

      final error = CacheExpiredException(
        lastUpdate: lastUpdate,
        staleDuration: staleDuration,
      );

      expect(error.lastUpdate, equals(lastUpdate));
      expect(error.staleDuration, equals(staleDuration));
      expect(error.toString(), contains('Last update'));
    });

    test('IncompleteCacheException includes day counts', () {
      final error = IncompleteCacheException(expectedDays: 7, actualDays: 3);

      expect(error.expectedDays, equals(7));
      expect(error.actualDays, equals(3));
      expect(error.message, contains('Expected 7 days, found 3 days'));
    });
  });

  group('Offline Behavior - Cache Status', () {
    late MockLocalStorage storage;
    late OfflineStateManager offlineManager;
    late Location testLocation;

    setUp(() {
      storage = MockLocalStorage();
      offlineManager = OfflineStateManager(storage: storage);
      testLocation = const Location(
        id: '1',
        province: 'Istanbul',
        district: 'Kadikoy',
        latitude: 40.9828,
        longitude: 29.0227,
      );
    });

    test('Cache status is notFound when no data exists', () async {
      final status = await offlineManager.getCacheStatus(
        location: testLocation,
      );

      expect(status.status, equals(CacheStatus.notFound));
      expect(status.hasData, isFalse);
      expect(status.isUsable, isFalse);
    });

    test('Cache status is available when data is fresh', () async {
      final today = DateTime.now();
      final normalizedToday = DateTime(today.year, today.month, today.day);

      final times = List.generate(8, (index) {
        final date = normalizedToday.add(Duration(days: index));
        return PrayerTime(
          fajr: DateTime(date.year, date.month, date.day, 5, 30),
          sunrise: DateTime(date.year, date.month, date.day, 7, 0),
          dhuhr: DateTime(date.year, date.month, date.day, 13, 15),
          asr: DateTime(date.year, date.month, date.day, 16, 30),
          maghrib: DateTime(date.year, date.month, date.day, 19, 0),
          isha: DateTime(date.year, date.month, date.day, 20, 30),
          date: date,
        );
      });

      await storage.savePrayerTimes(times, testLocation.id);
      await storage.saveLastUpdateTime(DateTime.now());

      final status = await offlineManager.getCacheStatus(
        location: testLocation,
      );

      expect(status.status, equals(CacheStatus.available));
      expect(status.hasData, isTrue);
      expect(status.isUsable, isTrue);
      expect(status.cachedDays, greaterThanOrEqualTo(7));
    });

    test('Cache status is stale when data is old but usable', () async {
      final today = DateTime.now();
      final normalizedToday = DateTime(today.year, today.month, today.day);

      final times = List.generate(8, (index) {
        final date = normalizedToday.add(Duration(days: index));
        return PrayerTime(
          fajr: DateTime(date.year, date.month, date.day, 5, 30),
          sunrise: DateTime(date.year, date.month, date.day, 7, 0),
          dhuhr: DateTime(date.year, date.month, date.day, 13, 15),
          asr: DateTime(date.year, date.month, date.day, 16, 30),
          maghrib: DateTime(date.year, date.month, date.day, 19, 0),
          isha: DateTime(date.year, date.month, date.day, 20, 30),
          date: date,
        );
      });

      await storage.savePrayerTimes(times, testLocation.id);
      await storage.saveLastUpdateTime(
        DateTime.now().subtract(const Duration(days: 2)),
      );

      final status = await offlineManager.getCacheStatus(
        location: testLocation,
      );

      expect(status.status, equals(CacheStatus.stale));
      expect(status.hasData, isTrue);
      expect(status.isUsable, isTrue);
    });

    test('Cache status is expired when data is too old', () async {
      final today = DateTime.now();
      final normalizedToday = DateTime(today.year, today.month, today.day);

      final times = List.generate(7, (index) {
        final date = normalizedToday.add(Duration(days: index));
        return PrayerTime(
          fajr: DateTime(date.year, date.month, date.day, 5, 30),
          sunrise: DateTime(date.year, date.month, date.day, 7, 0),
          dhuhr: DateTime(date.year, date.month, date.day, 13, 15),
          asr: DateTime(date.year, date.month, date.day, 16, 30),
          maghrib: DateTime(date.year, date.month, date.day, 19, 0),
          isha: DateTime(date.year, date.month, date.day, 20, 30),
          date: date,
        );
      });

      await storage.savePrayerTimes(times, testLocation.id);
      await storage.saveLastUpdateTime(
        DateTime.now().subtract(const Duration(days: 10)),
      );

      final status = await offlineManager.getCacheStatus(
        location: testLocation,
      );

      expect(status.status, equals(CacheStatus.expired));
      expect(status.hasData, isTrue);
      expect(status.isUsable, isFalse);
    });

    test('Cache status is incomplete when data has gaps', () async {
      final today = DateTime.now();
      final normalizedToday = DateTime(today.year, today.month, today.day);

      final times = List.generate(3, (index) {
        final date = normalizedToday.add(Duration(days: index));
        return PrayerTime(
          fajr: DateTime(date.year, date.month, date.day, 5, 30),
          sunrise: DateTime(date.year, date.month, date.day, 7, 0),
          dhuhr: DateTime(date.year, date.month, date.day, 13, 15),
          asr: DateTime(date.year, date.month, date.day, 16, 30),
          maghrib: DateTime(date.year, date.month, date.day, 19, 0),
          isha: DateTime(date.year, date.month, date.day, 20, 30),
          date: date,
        );
      });

      await storage.savePrayerTimes(times, testLocation.id);
      await storage.saveLastUpdateTime(DateTime.now());

      final status = await offlineManager.getCacheStatus(
        location: testLocation,
      );

      expect(status.status, equals(CacheStatus.incomplete));
      expect(status.hasData, isTrue);
      expect(status.cachedDays, equals(3));
    });

    test('Cache status is stale when no update timestamp exists', () async {
      final today = DateTime.now();
      final normalizedToday = DateTime(today.year, today.month, today.day);

      final times = List.generate(7, (index) {
        final date = normalizedToday.add(Duration(days: index));
        return PrayerTime(
          fajr: DateTime(date.year, date.month, date.day, 5, 30),
          sunrise: DateTime(date.year, date.month, date.day, 7, 0),
          dhuhr: DateTime(date.year, date.month, date.day, 13, 15),
          asr: DateTime(date.year, date.month, date.day, 16, 30),
          maghrib: DateTime(date.year, date.month, date.day, 19, 0),
          isha: DateTime(date.year, date.month, date.day, 20, 30),
          date: date,
        );
      });

      await storage.savePrayerTimes(times, testLocation.id);

      final status = await offlineManager.getCacheStatus(
        location: testLocation,
      );

      expect(status.status, equals(CacheStatus.stale));
      expect(status.lastUpdate, isNull);
    });
  });

  group('Offline Behavior - Offline Data Retrieval', () {
    late MockLocalStorage storage;
    late OfflineStateManager offlineManager;
    late Location testLocation;

    setUp(() {
      storage = MockLocalStorage();
      offlineManager = OfflineStateManager(storage: storage);
      testLocation = const Location(
        id: '1',
        province: 'Istanbul',
        district: 'Kadikoy',
        latitude: 40.9828,
        longitude: 29.0227,
      );
    });

    test('Can retrieve offline prayer times when cache exists', () async {
      final today = DateTime(2024, 1, 1);
      final times = List.generate(7, (index) {
        final date = today.add(Duration(days: index));
        return PrayerTime(
          fajr: DateTime(date.year, date.month, date.day, 5, 30),
          sunrise: DateTime(date.year, date.month, date.day, 7, 0),
          dhuhr: DateTime(date.year, date.month, date.day, 13, 15),
          asr: DateTime(date.year, date.month, date.day, 16, 30),
          maghrib: DateTime(date.year, date.month, date.day, 19, 0),
          isha: DateTime(date.year, date.month, date.day, 20, 30),
          date: date,
        );
      });

      await storage.savePrayerTimes(times, testLocation.id);

      final retrieved = await offlineManager.getOfflinePrayerTimes(
        location: testLocation,
        startDate: today,
        endDate: today.add(const Duration(days: 6)),
      );

      expect(retrieved.length, equals(7));
      expect(retrieved.first.date.day, equals(1));
    });

    test('Throws CacheNotFoundException when no cache exists', () async {
      expect(
        () => offlineManager.getOfflinePrayerTimes(
          location: testLocation,
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 7),
        ),
        throwsA(isA<CacheNotFoundException>()),
      );
    });

    test('Can retrieve offline daily prayer time', () async {
      final date = DateTime(2024, 1, 15);
      final time = PrayerTime(
        fajr: DateTime(date.year, date.month, date.day, 5, 30),
        sunrise: DateTime(date.year, date.month, date.day, 7, 0),
        dhuhr: DateTime(date.year, date.month, date.day, 13, 15),
        asr: DateTime(date.year, date.month, date.day, 16, 30),
        maghrib: DateTime(date.year, date.month, date.day, 19, 0),
        isha: DateTime(date.year, date.month, date.day, 20, 30),
        date: date,
      );

      await storage.savePrayerTimes([time], testLocation.id);

      final retrieved = await offlineManager.getOfflineDailyPrayerTime(
        location: testLocation,
        date: date,
      );

      expect(retrieved, isNotNull);
      expect(retrieved!.date.day, equals(15));
    });

    test('Returns null when daily prayer time not in cache', () async {
      final retrieved = await offlineManager.getOfflineDailyPrayerTime(
        location: testLocation,
        date: DateTime(2024, 1, 15),
      );

      expect(retrieved, isNull);
    });

    test('Can check if cache exists for specific date', () async {
      final date = DateTime(2024, 1, 15);

      expect(
        await offlineManager.hasCacheForDate(
          location: testLocation,
          date: date,
        ),
        isFalse,
      );

      final time = PrayerTime(
        fajr: DateTime(date.year, date.month, date.day, 5, 30),
        sunrise: DateTime(date.year, date.month, date.day, 7, 0),
        dhuhr: DateTime(date.year, date.month, date.day, 13, 15),
        asr: DateTime(date.year, date.month, date.day, 16, 30),
        maghrib: DateTime(date.year, date.month, date.day, 19, 0),
        isha: DateTime(date.year, date.month, date.day, 20, 30),
        date: date,
      );

      await storage.savePrayerTimes([time], testLocation.id);

      expect(
        await offlineManager.hasCacheForDate(
          location: testLocation,
          date: date,
        ),
        isTrue,
      );
    });

    test('Can check if cache exists for period', () async {
      final startDate = DateTime(2024, 1, 1);
      final endDate = DateTime(2024, 1, 7);

      expect(
        await offlineManager.hasCacheForPeriod(
          location: testLocation,
          startDate: startDate,
          endDate: endDate,
        ),
        isFalse,
      );

      final times = List.generate(7, (index) {
        final date = startDate.add(Duration(days: index));
        return PrayerTime(
          fajr: DateTime(date.year, date.month, date.day, 5, 30),
          sunrise: DateTime(date.year, date.month, date.day, 7, 0),
          dhuhr: DateTime(date.year, date.month, date.day, 13, 15),
          asr: DateTime(date.year, date.month, date.day, 16, 30),
          maghrib: DateTime(date.year, date.month, date.day, 19, 0),
          isha: DateTime(date.year, date.month, date.day, 20, 30),
          date: date,
        );
      });

      await storage.savePrayerTimes(times, testLocation.id);

      expect(
        await offlineManager.hasCacheForPeriod(
          location: testLocation,
          startDate: startDate,
          endDate: endDate,
        ),
        isTrue,
      );
    });
  });

  group('Offline Behavior - Repository with Network Failures', () {
    late MockLocalStorage storage;
    late MockPrayerTimeProvider provider;
    late PrayerTimesRepository repository;
    late Location testLocation;

    setUp(() {
      storage = MockLocalStorage();
      provider = MockPrayerTimeProvider();
      repository = PrayerTimesRepository(provider: provider, storage: storage);
      testLocation = const Location(
        id: '1',
        province: 'Istanbul',
        district: 'Kadikoy',
        latitude: 40.9828,
        longitude: 29.0227,
      );
    });

    test('Repository returns cached data when network fails', () async {
      final today = DateTime(2024, 1, 1);
      final times = List.generate(7, (index) {
        final date = today.add(Duration(days: index));
        return PrayerTime(
          fajr: DateTime(date.year, date.month, date.day, 5, 30),
          sunrise: DateTime(date.year, date.month, date.day, 7, 0),
          dhuhr: DateTime(date.year, date.month, date.day, 13, 15),
          asr: DateTime(date.year, date.month, date.day, 16, 30),
          maghrib: DateTime(date.year, date.month, date.day, 19, 0),
          isha: DateTime(date.year, date.month, date.day, 20, 30),
          date: date,
        );
      });

      await storage.savePrayerTimes(times, testLocation.id);

      provider.shouldThrowError = true;

      final retrieved = await repository.getPrayerTimes(
        location: testLocation,
        startDate: today,
        endDate: today.add(const Duration(days: 6)),
        forceRefresh: true,
      );

      expect(retrieved.length, equals(7));
    });

    test(
      'Repository throws error when network fails and no cache exists',
      () async {
        provider.shouldThrowError = true;

        expect(
          () => repository.getPrayerTimes(
            location: testLocation,
            startDate: DateTime(2024, 1, 1),
            endDate: DateTime(2024, 1, 7),
          ),
          throwsA(isA<NetworkException>()),
        );
      },
    );

    test('Repository uses cache first in offline mode', () async {
      final today = DateTime(2024, 1, 1);
      final times = List.generate(7, (index) {
        final date = today.add(Duration(days: index));
        return PrayerTime(
          fajr: DateTime(date.year, date.month, date.day, 5, 30),
          sunrise: DateTime(date.year, date.month, date.day, 7, 0),
          dhuhr: DateTime(date.year, date.month, date.day, 13, 15),
          asr: DateTime(date.year, date.month, date.day, 16, 30),
          maghrib: DateTime(date.year, date.month, date.day, 19, 0),
          isha: DateTime(date.year, date.month, date.day, 20, 30),
          date: date,
        );
      });

      await storage.savePrayerTimes(times, testLocation.id);

      provider.fetchCallCount = 0;
      provider.shouldThrowError = true;

      final retrieved = await repository.getPrayerTimes(
        location: testLocation,
        startDate: today,
        endDate: today.add(const Duration(days: 6)),
      );

      expect(retrieved.length, equals(7));
      expect(provider.fetchCallCount, equals(0));
    });

    test('Repository falls back to cache on partial network failure', () async {
      final today = DateTime(2024, 1, 1);

      final times = List.generate(7, (index) {
        final date = today.add(Duration(days: index));
        return PrayerTime(
          fajr: DateTime(date.year, date.month, date.day, 5, 30),
          sunrise: DateTime(date.year, date.month, date.day, 7, 0),
          dhuhr: DateTime(date.year, date.month, date.day, 13, 15),
          asr: DateTime(date.year, date.month, date.day, 16, 30),
          maghrib: DateTime(date.year, date.month, date.day, 19, 0),
          isha: DateTime(date.year, date.month, date.day, 20, 30),
          date: date,
        );
      });

      await storage.savePrayerTimes(times, testLocation.id);
      await storage.saveLastUpdateTime(DateTime.now());

      final retrieved1 = await repository.getPrayerTimes(
        location: testLocation,
        startDate: today,
        endDate: today.add(const Duration(days: 6)),
      );

      expect(retrieved1.length, equals(7));

      provider.shouldThrowError = true;

      final retrieved2 = await repository.getPrayerTimes(
        location: testLocation,
        startDate: today,
        endDate: today.add(const Duration(days: 6)),
        forceRefresh: true,
      );

      expect(retrieved2.length, equals(7));
    });

    test('Daily prayer time falls back to cache on network error', () async {
      final date = DateTime(2024, 1, 15);
      final time = PrayerTime(
        fajr: DateTime(date.year, date.month, date.day, 5, 30),
        sunrise: DateTime(date.year, date.month, date.day, 7, 0),
        dhuhr: DateTime(date.year, date.month, date.day, 13, 15),
        asr: DateTime(date.year, date.month, date.day, 16, 30),
        maghrib: DateTime(date.year, date.month, date.day, 19, 0),
        isha: DateTime(date.year, date.month, date.day, 20, 30),
        date: date,
      );

      await storage.savePrayerTimes([time], testLocation.id);

      provider.shouldThrowError = true;

      final retrieved = await repository.getDailyPrayerTime(
        location: testLocation,
        date: date,
        forceRefresh: true,
      );

      expect(retrieved, isNotNull);
      expect(retrieved!.date.day, equals(15));
    });
  });

  group('Offline Behavior - User Messages', () {
    late OfflineStateManager offlineManager;
    late MockLocalStorage storage;

    setUp(() {
      storage = MockLocalStorage();
      offlineManager = OfflineStateManager(storage: storage);
    });

    test('Cache status messages are in Turkish', () {
      expect(
        offlineManager.getCacheStatusMessage(CacheStatus.available),
        equals('Veriler güncel'),
      );
      expect(
        offlineManager.getCacheStatusMessage(CacheStatus.stale),
        equals('Veriler güncellenmeli'),
      );
      expect(
        offlineManager.getCacheStatusMessage(CacheStatus.expired),
        equals('Veriler çok eski, güncelleme gerekli'),
      );
      expect(
        offlineManager.getCacheStatusMessage(CacheStatus.notFound),
        equals('Veri bulunamadı'),
      );
      expect(
        offlineManager.getCacheStatusMessage(CacheStatus.incomplete),
        equals('Veriler eksik'),
      );
    });

    test('Offline message is in Turkish', () {
      expect(
        offlineManager.getOfflineMessage(),
        contains('İnternet bağlantısı yok'),
      );
    });

    test('No data message is in Turkish', () {
      expect(offlineManager.getNoDataMessage(), contains('Veri alınamadı'));
    });

    test('Update failed message is in Turkish', () {
      expect(
        offlineManager.getUpdateFailedMessage(),
        contains('Güncelleme başarısız'),
      );
    });
  });
}
