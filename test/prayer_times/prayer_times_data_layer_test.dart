import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/interfaces/prayer_time_provider.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/features/prayer_times/domain/prayer_times_repository.dart';

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
  Future<void> saveLastUpdateTime(DateTime time) async {
    _lastUpdateTime = time;
  }

  @override
  Future<DateTime?> getLastUpdateTime() async {
    return _lastUpdateTime;
  }
}

void main() {
  group('Prayer Times Data Layer - API Provider', () {
    late MockPrayerTimeProvider provider;
    late Location testLocation;

    setUp(() {
      provider = MockPrayerTimeProvider();
      testLocation = const Location(
        id: '1',
        province: 'Istanbul',
        district: 'Kadikoy',
        latitude: 40.9828,
        longitude: 29.0227,
      );
    });

    test('Provider can fetch multiple days of prayer times', () async {
      final startDate = DateTime(2024, 1, 1);
      final endDate = DateTime(2024, 1, 7);

      final times = await provider.fetchPrayerTimes(
        location: testLocation,
        startDate: startDate,
        endDate: endDate,
      );

      expect(times.length, equals(7));
      expect(times.first.date.day, equals(1));
      expect(times.last.date.day, equals(7));
    });

    test('Provider can fetch daily prayer time', () async {
      final date = DateTime(2024, 1, 15);

      final time = await provider.fetchDailyPrayerTime(
        location: testLocation,
        date: date,
      );

      expect(time, isNotNull);
      expect(time!.date.day, equals(15));
      expect(time.fajr.hour, equals(5));
      expect(time.fajr.minute, equals(30));
    });

    test('Provider throws error when network fails', () async {
      provider.shouldThrowError = true;

      expect(
        () => provider.fetchDailyPrayerTime(
          location: testLocation,
          date: DateTime.now(),
        ),
        throwsException,
      );
    });
  });

  group('Prayer Times Data Layer - SQLite Storage', () {
    late MockLocalStorage storage;
    late Location testLocation;

    setUp(() {
      storage = MockLocalStorage();
      testLocation = const Location(
        id: '1',
        province: 'Istanbul',
        district: 'Kadikoy',
      );
    });

    test('Storage can save and retrieve prayer times', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final prayerTime = PrayerTime(
        fajr: DateTime(today.year, today.month, today.day, 5, 30),
        sunrise: DateTime(today.year, today.month, today.day, 7, 0),
        dhuhr: DateTime(today.year, today.month, today.day, 13, 15),
        asr: DateTime(today.year, today.month, today.day, 16, 30),
        maghrib: DateTime(today.year, today.month, today.day, 19, 0),
        isha: DateTime(today.year, today.month, today.day, 20, 30),
        date: today,
      );

      await storage.savePrayerTimes([prayerTime], testLocation.id);

      final retrieved = await storage.getPrayerTimes(
        locationId: testLocation.id,
        startDate: today,
        endDate: today,
      );

      expect(retrieved.length, equals(1));
      expect(retrieved.first.fajr.hour, equals(5));
      expect(retrieved.first.fajr.minute, equals(30));
    });

    test('Storage can save and retrieve multiple days', () async {
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

      final retrieved = await storage.getPrayerTimes(
        locationId: testLocation.id,
        startDate: today,
        endDate: today.add(const Duration(days: 6)),
      );

      expect(retrieved.length, equals(7));
    });

    test('Storage can delete old prayer times', () async {
      final oldDate = DateTime(2024, 1, 1);
      final newDate = DateTime(2024, 2, 1);

      final oldTime = PrayerTime(
        fajr: oldDate,
        sunrise: oldDate,
        dhuhr: oldDate,
        asr: oldDate,
        maghrib: oldDate,
        isha: oldDate,
        date: oldDate,
      );

      final newTime = PrayerTime(
        fajr: newDate,
        sunrise: newDate,
        dhuhr: newDate,
        asr: newDate,
        maghrib: newDate,
        isha: newDate,
        date: newDate,
      );

      await storage.savePrayerTimes([oldTime, newTime], testLocation.id);

      await storage.deleteOldPrayerTimes(DateTime(2024, 1, 15));

      final retrieved = await storage.getPrayerTimes(
        locationId: testLocation.id,
        startDate: oldDate,
        endDate: newDate,
      );

      expect(retrieved.length, equals(1));
      expect(retrieved.first.date.month, equals(2));
    });

    test('Storage can save and retrieve last update time', () async {
      final now = DateTime.now();

      await storage.saveLastUpdateTime(now);
      final retrieved = await storage.getLastUpdateTime();

      expect(retrieved, isNotNull);
      expect(retrieved, equals(now));
    });
  });

  group('Prayer Times Data Layer - Repository with Cache Strategy', () {
    late MockPrayerTimeProvider provider;
    late MockLocalStorage storage;
    late PrayerTimesRepository repository;
    late Location testLocation;

    setUp(() {
      provider = MockPrayerTimeProvider();
      storage = MockLocalStorage();
      repository = PrayerTimesRepository(provider: provider, storage: storage);
      testLocation = const Location(
        id: '1',
        province: 'Istanbul',
        district: 'Kadikoy',
        latitude: 40.9828,
        longitude: 29.0227,
      );
    });

    test('Repository fetches from API when cache is empty', () async {
      final today = DateTime(2024, 1, 1);
      final endDate = today.add(const Duration(days: 6));

      final times = await repository.getPrayerTimes(
        location: testLocation,
        startDate: today,
        endDate: endDate,
      );

      expect(times.length, equals(7));
      expect(provider.fetchCallCount, equals(1));
    });

    test('Repository returns cache when available and complete', () async {
      final today = DateTime(2024, 1, 1);
      final endDate = today.add(const Duration(days: 6));

      await repository.getPrayerTimes(
        location: testLocation,
        startDate: today,
        endDate: endDate,
      );

      provider.fetchCallCount = 0;

      final times = await repository.getPrayerTimes(
        location: testLocation,
        startDate: today,
        endDate: endDate,
      );

      expect(times.length, equals(7));
      expect(provider.fetchCallCount, equals(0));
    });

    test('Repository fetches from API when forceRefresh is true', () async {
      final today = DateTime(2024, 1, 1);
      final endDate = today.add(const Duration(days: 6));

      await repository.getPrayerTimes(
        location: testLocation,
        startDate: today,
        endDate: endDate,
      );

      provider.fetchCallCount = 0;

      await repository.getPrayerTimes(
        location: testLocation,
        startDate: today,
        endDate: endDate,
        forceRefresh: true,
      );

      expect(provider.fetchCallCount, equals(1));
    });

    test('Repository saves prayer times to cache after API fetch', () async {
      final today = DateTime(2024, 1, 1);
      final endDate = today.add(const Duration(days: 6));

      await repository.getPrayerTimes(
        location: testLocation,
        startDate: today,
        endDate: endDate,
      );

      final cached = await storage.getPrayerTimes(
        locationId: testLocation.id,
        startDate: today,
        endDate: endDate,
      );

      expect(cached.length, equals(7));
    });

    test(
      'Repository updates last update time after successful fetch',
      () async {
        final today = DateTime(2024, 1, 1);
        final endDate = today.add(const Duration(days: 6));

        await repository.getPrayerTimes(
          location: testLocation,
          startDate: today,
          endDate: endDate,
        );

        final lastUpdate = await repository.getLastUpdateTime();
        expect(lastUpdate, isNotNull);
      },
    );

    test('Repository returns cache when API fails', () async {
      final today = DateTime(2024, 1, 1);
      final endDate = today.add(const Duration(days: 6));

      await repository.getPrayerTimes(
        location: testLocation,
        startDate: today,
        endDate: endDate,
      );

      provider.shouldThrowError = true;

      final times = await repository.getPrayerTimes(
        location: testLocation,
        startDate: today,
        endDate: endDate,
        forceRefresh: true,
      );

      expect(times.length, equals(7));
    });

    test('Repository throws error when API fails and cache is empty', () async {
      provider.shouldThrowError = true;

      expect(
        () => repository.getPrayerTimes(
          location: testLocation,
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 7),
        ),
        throwsException,
      );
    });

    test('Repository can fetch daily prayer time with caching', () async {
      final date = DateTime(2024, 1, 15);

      final time1 = await repository.getDailyPrayerTime(
        location: testLocation,
        date: date,
      );

      provider.fetchCallCount = 0;

      final time2 = await repository.getDailyPrayerTime(
        location: testLocation,
        date: date,
      );

      expect(time1, isNotNull);
      expect(time2, isNotNull);
      expect(provider.fetchCallCount, equals(0));
    });

    test('Repository can clean up old cache entries', () async {
      final oldDate = DateTime(2024, 1, 1);
      final newDate = DateTime.now();
      final newDateNormalized = DateTime(
        newDate.year,
        newDate.month,
        newDate.day,
      );

      await repository.getPrayerTimes(
        location: testLocation,
        startDate: oldDate,
        endDate: oldDate.add(const Duration(days: 6)),
      );

      await repository.getPrayerTimes(
        location: testLocation,
        startDate: newDateNormalized,
        endDate: newDateNormalized.add(const Duration(days: 6)),
      );

      await repository.cleanupOldCache();

      final oldCached = await storage.getPrayerTimes(
        locationId: testLocation.id,
        startDate: oldDate,
        endDate: oldDate.add(const Duration(days: 6)),
      );

      expect(oldCached.length, equals(0));
    });

    test('Repository can check if cache is stale', () async {
      expect(await repository.isCacheStale(), isTrue);

      final today = DateTime(2024, 1, 1);
      await repository.getPrayerTimes(
        location: testLocation,
        startDate: today,
        endDate: today.add(const Duration(days: 6)),
      );

      expect(await repository.isCacheStale(), isFalse);

      await storage.saveLastUpdateTime(
        DateTime.now().subtract(const Duration(days: 2)),
      );

      expect(await repository.isCacheStale(), isTrue);
    });

    test('Repository refreshPrayerTimes fetches 30 days forward', () async {
      await repository.refreshPrayerTimes(testLocation);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final endDate = today.add(const Duration(days: 30));

      final cached = await storage.getPrayerTimes(
        locationId: testLocation.id,
        startDate: today,
        endDate: endDate,
      );

      expect(cached.length, greaterThanOrEqualTo(30));
    });

    test('Repository handles incomplete cache correctly', () async {
      final today = DateTime(2024, 1, 1);

      final partialTime = PrayerTime(
        fajr: today,
        sunrise: today,
        dhuhr: today,
        asr: today,
        maghrib: today,
        isha: today,
        date: today,
      );
      await storage.savePrayerTimes([partialTime], testLocation.id);

      provider.fetchCallCount = 0;

      final times = await repository.getPrayerTimes(
        location: testLocation,
        startDate: today,
        endDate: today.add(const Duration(days: 6)),
      );

      expect(times.length, equals(7));
      expect(provider.fetchCallCount, equals(1));
    });
  });

  group('Prayer Times Data Layer - Cache Strategy Edge Cases', () {
    late MockPrayerTimeProvider provider;
    late MockLocalStorage storage;
    late PrayerTimesRepository repository;
    late Location testLocation;

    setUp(() {
      provider = MockPrayerTimeProvider();
      storage = MockLocalStorage();
      repository = PrayerTimesRepository(provider: provider, storage: storage);
      testLocation = const Location(
        id: '1',
        province: 'Istanbul',
        district: 'Kadikoy',
        latitude: 40.9828,
        longitude: 29.0227,
      );
    });

    test('Repository handles single day request correctly', () async {
      final date = DateTime(2024, 1, 15);

      final times = await repository.getPrayerTimes(
        location: testLocation,
        startDate: date,
        endDate: date,
      );

      expect(times.length, equals(1));
      expect(times.first.date.day, equals(15));
    });

    test('Repository handles cache with gaps correctly', () async {
      final today = DateTime(2024, 1, 1);

      final time1 = PrayerTime(
        fajr: today,
        sunrise: today,
        dhuhr: today,
        asr: today,
        maghrib: today,
        isha: today,
        date: today,
      );

      final time3 = PrayerTime(
        fajr: today.add(const Duration(days: 2)),
        sunrise: today.add(const Duration(days: 2)),
        dhuhr: today.add(const Duration(days: 2)),
        asr: today.add(const Duration(days: 2)),
        maghrib: today.add(const Duration(days: 2)),
        isha: today.add(const Duration(days: 2)),
        date: today.add(const Duration(days: 2)),
      );

      await storage.savePrayerTimes([time1, time3], testLocation.id);

      provider.fetchCallCount = 0;

      await repository.getPrayerTimes(
        location: testLocation,
        startDate: today,
        endDate: today.add(const Duration(days: 2)),
      );

      expect(provider.fetchCallCount, equals(1));
    });

    test('Last update time is properly formatted', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await repository.getPrayerTimes(
        location: testLocation,
        startDate: today,
        endDate: today,
      );

      final lastUpdate = await repository.getLastUpdateTime();
      expect(lastUpdate, isNotNull);
      expect(
        lastUpdate!.isBefore(DateTime.now().add(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        lastUpdate.isAfter(
          DateTime.now().subtract(const Duration(seconds: 10)),
        ),
        isTrue,
      );
    });
  });
}
