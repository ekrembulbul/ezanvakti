import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/interfaces/prayer_time_provider.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/calculation_settings.dart';
import 'package:ezanvakti/core/interfaces/notification_service.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';

class MockPrayerTimeProvider implements PrayerTimeProvider {
  @override
  String get providerName => 'Mock Provider';

  @override
  Future<List<PrayerTime>> fetchPrayerTimes({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final now = DateTime.now();
    return [
      PrayerTime(
        fajr: DateTime(now.year, now.month, now.day, 5, 30),
        sunrise: DateTime(now.year, now.month, now.day, 7, 0),
        dhuhr: DateTime(now.year, now.month, now.day, 13, 15),
        asr: DateTime(now.year, now.month, now.day, 16, 30),
        maghrib: DateTime(now.year, now.month, now.day, 19, 0),
        isha: DateTime(now.year, now.month, now.day, 20, 30),
        date: now,
      ),
    ];
  }

  @override
  Future<PrayerTime?> fetchDailyPrayerTime({
    required Location location,
    required DateTime date,
  }) async {
    return PrayerTime(
      fajr: DateTime(date.year, date.month, date.day, 5, 30),
      sunrise: DateTime(date.year, date.month, date.day, 7, 0),
      dhuhr: DateTime(date.year, date.month, date.day, 13, 15),
      asr: DateTime(date.year, date.month, date.day, 16, 30),
      maghrib: DateTime(date.year, date.month, date.day, 19, 0),
      isha: DateTime(date.year, date.month, date.day, 20, 30),
      date: date,
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
    _prayerTimesCache[locationId] = prayerTimes;
  }

  @override
  Future<List<PrayerTime>> getPrayerTimes({
    required String locationId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final times = _prayerTimesCache[locationId] ?? [];
    return times.where((pt) {
      return pt.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
          pt.date.isBefore(endDate.add(const Duration(days: 1)));
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
          .where((pt) => pt.date.isAfter(cutoffDate))
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

  @override
  Future<void> saveLastUpdateTime(DateTime time) async {
    _lastUpdateTime = time;
  }

  @override
  Future<DateTime?> getLastUpdateTime() async {
    return _lastUpdateTime;
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
    _scheduledNotifications.clear();
  }

  @override
  Future<List<ScheduledNotification>> getPendingNotifications() async {
    return _scheduledNotifications.values.toList();
  }
}

void main() {
  group('Setup Tests - Module Imports', () {
    test('All core modules can be imported successfully', () {
      expect(PrayerTimeProvider, isNotNull);
      expect(LocalStorage, isNotNull);
      expect(NotificationService, isNotNull);
      expect(PrayerTime, isNotNull);
      expect(Location, isNotNull);
      expect(NotificationSetting, isNotNull);
    });

    test('Prayer time model can be instantiated', () {
      final now = DateTime.now();
      final prayerTime = PrayerTime(
        fajr: now,
        sunrise: now,
        dhuhr: now,
        asr: now,
        maghrib: now,
        isha: now,
        date: now,
      );

      expect(prayerTime.fajr, equals(now));
      expect(prayerTime.date, equals(now));
    });

    test('Location model can be instantiated', () {
      const location = Location(
        id: '1',
        province: 'Istanbul',
        district: 'Kadikoy',
      );

      expect(location.id, equals('1'));
      expect(location.province, equals('Istanbul'));
      expect(location.district, equals('Kadikoy'));
    });

    test('NotificationSetting model can be instantiated', () {
      const setting = NotificationSetting(
        prayerType: PrayerType.fajr,
        isActive: true,
        minutesBefore: 5,
      );

      expect(setting.prayerType, equals(PrayerType.fajr));
      expect(setting.isActive, isTrue);
      expect(setting.minutesBefore, equals(5));
    });
  });

  group('Setup Tests - API Adapter Interface', () {
    late MockPrayerTimeProvider mockProvider;

    setUp(() {
      mockProvider = MockPrayerTimeProvider();
    });

    test('Mock prayer time provider is defined and implements interface', () {
      expect(mockProvider, isA<PrayerTimeProvider>());
      expect(mockProvider.providerName, equals('Mock Provider'));
    });

    test('Mock provider can fetch prayer times', () async {
      const location = Location(
        id: '1',
        province: 'Istanbul',
        district: 'Kadikoy',
      );

      final times = await mockProvider.fetchPrayerTimes(
        location: location,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
      );

      expect(times, isNotEmpty);
      expect(times.first, isA<PrayerTime>());
    });

    test('Mock provider can fetch daily prayer time', () async {
      const location = Location(
        id: '1',
        province: 'Istanbul',
        district: 'Kadikoy',
      );

      final time = await mockProvider.fetchDailyPrayerTime(
        location: location,
        date: DateTime.now(),
      );

      expect(time, isNotNull);
      expect(time, isA<PrayerTime>());
    });
  });

  group('Setup Tests - SQLite Storage Interface', () {
    late MockLocalStorage mockStorage;

    setUp(() {
      mockStorage = MockLocalStorage();
    });

    test('Mock storage is defined and implements interface', () {
      expect(mockStorage, isA<LocalStorage>());
    });

    test('Mock storage can initialize', () async {
      await expectLater(mockStorage.init(), completes);
    });

    test(
      'Mock storage can save and retrieve prayer times (CRUD - Create/Read)',
      () async {
        final now = DateTime.now();
        final prayerTime = PrayerTime(
          fajr: DateTime(now.year, now.month, now.day, 5, 30),
          sunrise: DateTime(now.year, now.month, now.day, 7, 0),
          dhuhr: DateTime(now.year, now.month, now.day, 13, 15),
          asr: DateTime(now.year, now.month, now.day, 16, 30),
          maghrib: DateTime(now.year, now.month, now.day, 19, 0),
          isha: DateTime(now.year, now.month, now.day, 20, 30),
          date: now,
        );

        await mockStorage.savePrayerTimes([prayerTime], 'location1');

        final retrieved = await mockStorage.getPrayerTimes(
          locationId: 'location1',
          startDate: now.subtract(const Duration(days: 1)),
          endDate: now.add(const Duration(days: 1)),
        );

        expect(retrieved, isNotEmpty);
        expect(retrieved.first.fajr, equals(prayerTime.fajr));
      },
    );

    test('Mock storage can save and retrieve daily prayer time', () async {
      final now = DateTime.now();
      final prayerTime = PrayerTime(
        fajr: DateTime(now.year, now.month, now.day, 5, 30),
        sunrise: DateTime(now.year, now.month, now.day, 7, 0),
        dhuhr: DateTime(now.year, now.month, now.day, 13, 15),
        asr: DateTime(now.year, now.month, now.day, 16, 30),
        maghrib: DateTime(now.year, now.month, now.day, 19, 0),
        isha: DateTime(now.year, now.month, now.day, 20, 30),
        date: now,
      );

      await mockStorage.savePrayerTimes([prayerTime], 'location1');

      final retrieved = await mockStorage.getDailyPrayerTime(
        locationId: 'location1',
        date: now,
      );

      expect(retrieved, isNotNull);
      expect(retrieved!.fajr, equals(prayerTime.fajr));
    });

    test('Mock storage can delete old prayer times (CRUD - Delete)', () async {
      final now = DateTime.now();
      final oldDate = now.subtract(const Duration(days: 10));
      final newDate = now;

      final oldPrayerTime = PrayerTime(
        fajr: oldDate,
        sunrise: oldDate,
        dhuhr: oldDate,
        asr: oldDate,
        maghrib: oldDate,
        isha: oldDate,
        date: oldDate,
      );

      final newPrayerTime = PrayerTime(
        fajr: newDate,
        sunrise: newDate,
        dhuhr: newDate,
        asr: newDate,
        maghrib: newDate,
        isha: newDate,
        date: newDate,
      );

      await mockStorage.savePrayerTimes([
        oldPrayerTime,
        newPrayerTime,
      ], 'location1');
      await mockStorage.deleteOldPrayerTimes(
        now.subtract(const Duration(days: 5)),
      );

      final retrieved = await mockStorage.getPrayerTimes(
        locationId: 'location1',
        startDate: oldDate,
        endDate: newDate.add(const Duration(days: 1)),
      );

      expect(retrieved.length, equals(1));
      expect(retrieved.first.date, equals(newDate));
    });

    test('Mock storage can save and retrieve active location', () async {
      const location = Location(
        id: '1',
        province: 'Istanbul',
        district: 'Kadikoy',
      );

      await mockStorage.saveActiveLocation(location);
      final retrieved = await mockStorage.getActiveLocation();

      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('1'));
      expect(retrieved.province, equals('Istanbul'));
    });

    test('Mock storage can save and retrieve notification settings', () async {
      const settings = [
        NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 5,
        ),
        NotificationSetting(prayerType: PrayerType.dhuhr, isActive: false),
      ];

      await mockStorage.saveNotificationSettings(settings);
      final retrieved = await mockStorage.getNotificationSettings();

      expect(retrieved.length, equals(2));
      expect(retrieved.first.prayerType, equals(PrayerType.fajr));
      expect(retrieved.first.isActive, isTrue);
    });

    test('Mock storage can save and retrieve last update time', () async {
      final now = DateTime.now();

      await mockStorage.saveLastUpdateTime(now);
      final retrieved = await mockStorage.getLastUpdateTime();

      expect(retrieved, isNotNull);
      expect(retrieved, equals(now));
    });
  });

  group('Setup Tests - Notification Platform Service', () {
    late MockNotificationService mockService;

    setUp(() {
      mockService = MockNotificationService();
    });

    test('Mock notification service is defined and implements interface', () {
      expect(mockService, isA<NotificationService>());
    });

    test('Mock notification service can initialize', () async {
      await expectLater(mockService.init(), completes);
    });

    test(
      'Mock notification service can request and check permission',
      () async {
        expect(await mockService.isPermissionGranted(), isFalse);

        final granted = await mockService.requestPermission();
        expect(granted, isTrue);
        expect(await mockService.isPermissionGranted(), isTrue);
      },
    );

    test('Mock notification service can schedule notification', () async {
      final scheduledTime = DateTime.now().add(const Duration(hours: 1));

      await mockService.scheduleNotification(
        id: 'test_notification',
        scheduledTime: scheduledTime,
        title: 'Test',
        body: 'Test notification',
      );

      final pending = await mockService.getPendingNotifications();
      expect(pending.length, equals(1));
      expect(pending.first.id, equals('test_notification'));
    });

    test(
      'Mock notification service can cancel specific notification',
      () async {
        final scheduledTime = DateTime.now().add(const Duration(hours: 1));

        await mockService.scheduleNotification(
          id: 'test_notification_1',
          scheduledTime: scheduledTime,
          title: 'Test 1',
          body: 'Test notification 1',
        );

        await mockService.scheduleNotification(
          id: 'test_notification_2',
          scheduledTime: scheduledTime,
          title: 'Test 2',
          body: 'Test notification 2',
        );

        await mockService.cancelNotification('test_notification_1');

        final pending = await mockService.getPendingNotifications();
        expect(pending.length, equals(1));
        expect(pending.first.id, equals('test_notification_2'));
      },
    );

    test('Mock notification service can cancel all notifications', () async {
      final scheduledTime = DateTime.now().add(const Duration(hours: 1));

      await mockService.scheduleNotification(
        id: 'test_notification_1',
        scheduledTime: scheduledTime,
        title: 'Test 1',
        body: 'Test notification 1',
      );

      await mockService.scheduleNotification(
        id: 'test_notification_2',
        scheduledTime: scheduledTime,
        title: 'Test 2',
        body: 'Test notification 2',
      );

      await mockService.cancelAllNotifications();

      final pending = await mockService.getPendingNotifications();
      expect(pending, isEmpty);
    });
  });

  group('Setup Tests - Dependency Injection', () {
    test('Mock implementations can be injected and used together', () async {
      final provider = MockPrayerTimeProvider();
      final storage = MockLocalStorage();
      final notificationService = MockNotificationService();

      await storage.init();
      await notificationService.init();

      const location = Location(
        id: '1',
        province: 'Istanbul',
        district: 'Kadikoy',
      );

      await storage.saveActiveLocation(location);

      final times = await provider.fetchPrayerTimes(
        location: location,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
      );

      await storage.savePrayerTimes(times, location.id);

      final retrieved = await storage.getPrayerTimes(
        locationId: location.id,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
      );

      expect(retrieved, isNotEmpty);

      await notificationService.requestPermission();
      expect(await notificationService.isPermissionGranted(), isTrue);

      await notificationService.scheduleNotification(
        id: 'fajr_notification',
        scheduledTime: retrieved.first.fajr,
        title: 'Fajr Prayer',
        body: 'Time for Fajr prayer',
      );

      final pending = await notificationService.getPendingNotifications();
      expect(pending, isNotEmpty);
    });
  });
}
