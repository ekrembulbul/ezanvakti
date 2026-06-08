import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/calculation_settings.dart';
import 'package:ezanvakti/core/interfaces/notification_service.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/features/notifications/domain/notification_scheduler.dart';
import 'package:ezanvakti/features/notifications/domain/notification_settings_manager.dart';
import 'package:ezanvakti/features/notifications/domain/default_notification_settings.dart';

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
    return _prayerTimesCache[locationId] ?? [];
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
    _notificationSettings = List.from(settings);
  }

  @override
  Future<List<NotificationSetting>> getNotificationSettings() async {
    return List.from(_notificationSettings);
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
}

class MockNotificationService implements NotificationService {
  final List<ScheduledNotification> _scheduledNotifications = [];
  bool _permissionGranted = true;
  int scheduleCallCount = 0;

  @override
  Future<void> openExactAlarmSettings() async {}
  int cancelAllCallCount = 0;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async {
    return _permissionGranted;
  }

  @override
  Future<bool> isPermissionGranted() async {
    return _permissionGranted;
  }

  void setPermissionGranted(bool granted) {
    _permissionGranted = granted;
  }

  @override
  Future<void> scheduleNotification({
    required String id,
    required DateTime scheduledTime,
    required String title,
    required String body,
  }) async {
    scheduleCallCount++;

    _scheduledNotifications.removeWhere((n) => n.id == id);

    _scheduledNotifications.add(
      ScheduledNotification(
        id: id,
        scheduledTime: scheduledTime,
        prayerType: PrayerType.fajr,
        minutesBefore: 0,
      ),
    );
  }

  @override
  Future<void> cancelNotification(String id) async {
    _scheduledNotifications.removeWhere((n) => n.id == id);
  }

  @override
  Future<void> cancelAllNotifications() async {
    cancelAllCallCount++;
    _scheduledNotifications.clear();
  }

  @override
  Future<List<ScheduledNotification>> getPendingNotifications() async {
    return List.from(_scheduledNotifications);
  }

  List<ScheduledNotification> get scheduledNotifications =>
      _scheduledNotifications;
}

void main() {
  group('Notification Settings Manager - CRUD Operations', () {
    late MockLocalStorage storage;
    late NotificationSettingsManager manager;

    setUp(() {
      storage = MockLocalStorage();
      manager = NotificationSettingsManager(storage: storage);
    });

    test('ensureDefaultsSeeded creates defaults on first launch', () async {
      expect(await manager.getSettings(), isEmpty);

      await manager.ensureDefaultsSeeded();

      expect(
        await manager.getSettings(),
        hasLength(defaultNotificationSettings.length),
      );
    });

    test(
      'ensureDefaultsSeeded does not recreate defaults after user clears them',
      () async {
        // İlk açılış: varsayılanlar oluşur ve bayrak işaretlenir.
        await manager.ensureDefaultsSeeded();
        expect(await manager.getSettings(), isNotEmpty);

        // Kullanıcı tüm bildirimleri siler.
        await manager.saveSettings([]);
        expect(await manager.getSettings(), isEmpty);

        // Konum değişimi vb. yeniden tetiklese de geri GELMEMELİ.
        await manager.ensureDefaultsSeeded();
        expect(await manager.getSettings(), isEmpty);
      },
    );

    test(
      'ensureDefaultsSeeded preserves pre-flag installs without reseeding',
      () async {
        // Bayrak öncesi kurulum: ayar var ama "tohumlandı" işareti yok.
        await manager.saveSettings([
          const NotificationSetting(
            prayerType: PrayerType.fajr,
            isActive: false,
            minutesBefore: 15,
          ),
        ]);

        await manager.ensureDefaultsSeeded();

        final settings = await manager.getSettings();
        expect(settings, hasLength(1));
        expect(settings.first.minutesBefore, equals(15));
        expect(settings.first.isActive, isFalse);
      },
    );

    test('Can save and retrieve settings', () async {
      final settings = [
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 0,
        ),
        const NotificationSetting(
          prayerType: PrayerType.dhuhr,
          isActive: true,
          minutesBefore: 10,
        ),
      ];

      await manager.saveSettings(settings);
      final retrieved = await manager.getSettings();

      expect(retrieved.length, equals(2));
      expect(retrieved[0].prayerType, equals(PrayerType.fajr));
      expect(retrieved[1].minutesBefore, equals(10));
    });

    test('Can update existing setting', () async {
      final initial = const NotificationSetting(
        prayerType: PrayerType.fajr,
        isActive: true,
        minutesBefore: 0,
      );

      await manager.saveSettings([initial]);

      final updated = initial.copyWith(isActive: false);
      await manager.updateSetting(updated);

      final settings = await manager.getSettings();
      expect(settings.length, equals(1));
      expect(settings[0].isActive, isFalse);
      expect(settings[0].minutesBefore, equals(0));
    });

    test('Can add new setting', () async {
      final setting1 = const NotificationSetting(
        prayerType: PrayerType.fajr,
        isActive: true,
        minutesBefore: 0,
      );

      await manager.saveSettings([setting1]);

      final setting2 = const NotificationSetting(
        prayerType: PrayerType.dhuhr,
        isActive: true,
        minutesBefore: 5,
      );

      await manager.updateSetting(setting2);

      final settings = await manager.getSettings();
      expect(settings.length, equals(2));
    });

    test('Can remove setting', () async {
      final settings = [
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 0,
        ),
        const NotificationSetting(
          prayerType: PrayerType.dhuhr,
          isActive: true,
          minutesBefore: 10,
        ),
      ];

      await manager.saveSettings(settings);

      await manager.removeSetting(
        prayerType: PrayerType.fajr,
        minutesBefore: 0,
      );

      final remaining = await manager.getSettings();
      expect(remaining.length, equals(1));
      expect(remaining[0].prayerType, equals(PrayerType.dhuhr));
    });

    test('Can get specific setting', () async {
      final settings = [
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 0,
        ),
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 10,
        ),
      ];

      await manager.saveSettings(settings);

      final setting = await manager.getSetting(
        prayerType: PrayerType.fajr,
        minutesBefore: 10,
      );

      expect(setting, isNotNull);
      expect(setting!.minutesBefore, equals(10));
    });

    test('Returns null for non-existent setting', () async {
      final setting = await manager.getSetting(
        prayerType: PrayerType.fajr,
        minutesBefore: 0,
      );
      expect(setting, isNull);
    });
  });

  group('Notification Settings Manager - Toggle Operations', () {
    late MockLocalStorage storage;
    late NotificationSettingsManager manager;

    setUp(() {
      storage = MockLocalStorage();
      manager = NotificationSettingsManager(storage: storage);
    });

    test('Can toggle individual setting', () async {
      final setting = const NotificationSetting(
        prayerType: PrayerType.fajr,
        isActive: true,
        minutesBefore: 0,
      );

      await manager.saveSettings([setting]);

      await manager.toggleSetting(
        prayerType: PrayerType.fajr,
        minutesBefore: 0,
      );

      final settings = await manager.getSettings();
      expect(settings[0].isActive, isFalse);

      await manager.toggleSetting(
        prayerType: PrayerType.fajr,
        minutesBefore: 0,
      );

      final settingsAgain = await manager.getSettings();
      expect(settingsAgain[0].isActive, isTrue);
    });

    test('Can enable all settings for a prayer', () async {
      final settings = [
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: false,
          minutesBefore: 0,
        ),
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: false,
          minutesBefore: 10,
        ),
        const NotificationSetting(
          prayerType: PrayerType.dhuhr,
          isActive: false,
          minutesBefore: 0,
        ),
      ];

      await manager.saveSettings(settings);

      await manager.enableAllForPrayer(PrayerType.fajr);

      final updated = await manager.getSettings();
      final fajrSettings = updated.where(
        (s) => s.prayerType == PrayerType.fajr,
      );

      expect(fajrSettings.every((s) => s.isActive), isTrue);
      expect(
        updated.firstWhere((s) => s.prayerType == PrayerType.dhuhr).isActive,
        isFalse,
      );
    });

    test('Can disable all settings for a prayer', () async {
      final settings = [
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 0,
        ),
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 10,
        ),
        const NotificationSetting(
          prayerType: PrayerType.dhuhr,
          isActive: true,
          minutesBefore: 0,
        ),
      ];

      await manager.saveSettings(settings);

      await manager.disableAllForPrayer(PrayerType.fajr);

      final updated = await manager.getSettings();
      final fajrSettings = updated.where(
        (s) => s.prayerType == PrayerType.fajr,
      );

      expect(fajrSettings.every((s) => !s.isActive), isTrue);
      expect(
        updated.firstWhere((s) => s.prayerType == PrayerType.dhuhr).isActive,
        isTrue,
      );
    });

    test('Can enable all settings', () async {
      final settings = [
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: false,
          minutesBefore: 0,
        ),
        const NotificationSetting(
          prayerType: PrayerType.dhuhr,
          isActive: false,
          minutesBefore: 0,
        ),
      ];

      await manager.saveSettings(settings);

      await manager.enableAll();

      final updated = await manager.getSettings();
      expect(updated.every((s) => s.isActive), isTrue);
    });

    test('Can disable all settings', () async {
      final settings = [
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 0,
        ),
        const NotificationSetting(
          prayerType: PrayerType.dhuhr,
          isActive: true,
          minutesBefore: 0,
        ),
      ];

      await manager.saveSettings(settings);

      await manager.disableAll();

      final updated = await manager.getSettings();
      expect(updated.every((s) => !s.isActive), isTrue);
    });
  });

  group('Notification Settings Manager - Query Operations', () {
    late MockLocalStorage storage;
    late NotificationSettingsManager manager;

    setUp(() {
      storage = MockLocalStorage();
      manager = NotificationSettingsManager(storage: storage);
    });

    test('Can get active settings only', () async {
      final settings = [
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 0,
        ),
        const NotificationSetting(
          prayerType: PrayerType.dhuhr,
          isActive: false,
          minutesBefore: 0,
        ),
        const NotificationSetting(
          prayerType: PrayerType.asr,
          isActive: true,
          minutesBefore: 10,
        ),
      ];

      await manager.saveSettings(settings);

      final active = await manager.getActiveSettings();
      expect(active.length, equals(2));
      expect(active.every((s) => s.isActive), isTrue);
    });

    test('Can get settings for specific prayer', () async {
      final settings = [
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 0,
        ),
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 10,
        ),
        const NotificationSetting(
          prayerType: PrayerType.dhuhr,
          isActive: true,
          minutesBefore: 0,
        ),
      ];

      await manager.saveSettings(settings);

      final fajrSettings = await manager.getSettingsForPrayer(PrayerType.fajr);
      expect(fajrSettings.length, equals(2));
      expect(
        fajrSettings.every((s) => s.prayerType == PrayerType.fajr),
        isTrue,
      );
    });

    test('Can check if has active settings', () async {
      expect(await manager.hasActiveSettings(), isFalse);

      await manager.saveSettings([
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: false,
          minutesBefore: 0,
        ),
      ]);

      expect(await manager.hasActiveSettings(), isFalse);

      await manager.saveSettings([
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 0,
        ),
      ]);

      expect(await manager.hasActiveSettings(), isTrue);
    });

    test('Can get active notification count', () async {
      final settings = [
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 0,
        ),
        const NotificationSetting(
          prayerType: PrayerType.dhuhr,
          isActive: false,
          minutesBefore: 0,
        ),
        const NotificationSetting(
          prayerType: PrayerType.asr,
          isActive: true,
          minutesBefore: 10,
        ),
      ];

      await manager.saveSettings(settings);

      final count = await manager.getActiveNotificationCount();
      expect(count, equals(2));
    });

    test('Can get settings grouped by prayer', () async {
      final settings = [
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 0,
        ),
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 10,
        ),
        const NotificationSetting(
          prayerType: PrayerType.dhuhr,
          isActive: true,
          minutesBefore: 0,
        ),
      ];

      await manager.saveSettings(settings);

      final grouped = await manager.getSettingsGroupedByPrayer();

      expect(grouped.keys.length, equals(2));
      expect(grouped[PrayerType.fajr]!.length, equals(2));
      expect(grouped[PrayerType.dhuhr]!.length, equals(1));
    });
  });

  group('Notification Settings Manager - Default Settings', () {
    late MockLocalStorage storage;
    late NotificationSettingsManager manager;

    setUp(() {
      storage = MockLocalStorage();
      manager = NotificationSettingsManager(storage: storage);
    });

    test('Can create default settings', () async {
      await manager.createDefaultSettings();

      final settings = await manager.getSettings();

      expect(settings, isNotEmpty);
      // All default settings are enabled out of the box.
      expect(settings.every((s) => s.isActive), isTrue);
      expect(
        settings.where((s) => s.prayerType == PrayerType.fajr).first.isActive,
        isTrue,
      );
    });

    test('Default settings include both on-time and early reminders', () async {
      await manager.createDefaultSettings();

      final settings = await manager.getSettings();

      expect(settings.any((s) => s.minutesBefore == 0), isTrue);
      expect(settings.any((s) => s.minutesBefore > 0), isTrue);
    });
  });

  group('Notification Scheduler - Basic Scheduling', () {
    late MockLocalStorage storage;
    late MockNotificationService notificationService;
    late NotificationScheduler scheduler;
    late Location testLocation;

    setUp(() {
      storage = MockLocalStorage();
      notificationService = MockNotificationService();
      scheduler = NotificationScheduler(
        notificationService: notificationService,
        storage: storage,
      );
      testLocation = const Location(
        id: '1',
        province: 'Istanbul',
        district: 'Kadikoy',
        latitude: 40.9828,
        longitude: 29.0227,
      );
    });

    test('Bounds scheduling to the day window and iOS cap', () async {
      await storage.saveNotificationSettings(defaultNotificationSettings);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final prayerTimes = List.generate(30, (i) {
        final d = today.add(Duration(days: i + 1));
        return PrayerTime(
          fajr: DateTime(d.year, d.month, d.day, 5, 30),
          sunrise: DateTime(d.year, d.month, d.day, 7, 0),
          dhuhr: DateTime(d.year, d.month, d.day, 13, 15),
          asr: DateTime(d.year, d.month, d.day, 16, 30),
          maghrib: DateTime(d.year, d.month, d.day, 19, 0),
          isha: DateTime(d.year, d.month, d.day, 20, 30),
          date: d,
        );
      });

      await scheduler.scheduleNotifications(
        location: testLocation,
        prayerTimes: prayerTimes,
      );

      final scheduled = notificationService.scheduledNotifications;
      expect(scheduled, isNotEmpty);
      // iOS tavanini asmamali.
      expect(
        scheduled.length,
        lessThanOrEqualTo(NotificationScheduler.maxScheduledNotifications),
      );
      // Pencere disindaki (>scheduleDaysAhead) hicbir bildirim planlanmamali.
      final cutoff = now.add(
        const Duration(days: NotificationScheduler.scheduleDaysAhead),
      );
      for (final n in scheduled) {
        expect(n.scheduledTime.isAfter(cutoff), isFalse);
      }
    });

    test('Empty settings still cancels previously scheduled notifications',
        () async {
      // Daha once OS'a zamanlanmis bir bildirim olsun (kullanici silmeden once
      // varsayilanlarin planladigi gibi).
      await notificationService.scheduleNotification(
        id: '12345',
        scheduledTime: DateTime.now().add(const Duration(hours: 1)),
        title: 'Eski',
        body: 'Eski bildirim',
      );
      expect(notificationService.scheduledNotifications, isNotEmpty);

      // Ayar listesi bos (kullanici hepsini sildi); storage'a hic ayar kaydedilmedi.
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final prayerTimes = [
        PrayerTime(
          fajr: DateTime(today.year, today.month, today.day, 5, 30),
          sunrise: DateTime(today.year, today.month, today.day, 7, 0),
          dhuhr: DateTime(today.year, today.month, today.day, 13, 15),
          asr: DateTime(today.year, today.month, today.day, 16, 30),
          maghrib: DateTime(today.year, today.month, today.day, 19, 0),
          isha: DateTime(today.year, today.month, today.day, 20, 30),
          date: today.add(const Duration(days: 1)),
        ),
      ];

      notificationService.cancelAllCallCount = 0;
      await scheduler.scheduleNotifications(
        location: testLocation,
        prayerTimes: prayerTimes,
      );

      // Bos ayarda bile cancelAll cagrilmali; eski bildirimler temizlenmeli.
      expect(notificationService.cancelAllCallCount, equals(1));
      expect(notificationService.scheduledNotifications, isEmpty);
    });

    test('Schedules notifications for active settings', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowNormalized = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
      );

      final prayerTime = PrayerTime(
        fajr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          5,
          30,
        ),
        sunrise: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          7,
          0,
        ),
        dhuhr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          13,
          15,
        ),
        asr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          16,
          30,
        ),
        maghrib: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          19,
          0,
        ),
        isha: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          20,
          30,
        ),
        date: tomorrowNormalized,
      );

      await storage.saveNotificationSettings([
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 0,
        ),
      ]);

      await scheduler.scheduleNotifications(
        location: testLocation,
        prayerTimes: [prayerTime],
      );

      expect(notificationService.scheduledNotifications.length, equals(1));
    });

    test('Does not schedule for inactive settings', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowNormalized = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
      );

      final prayerTime = PrayerTime(
        fajr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          5,
          30,
        ),
        sunrise: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          7,
          0,
        ),
        dhuhr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          13,
          15,
        ),
        asr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          16,
          30,
        ),
        maghrib: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          19,
          0,
        ),
        isha: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          20,
          30,
        ),
        date: tomorrowNormalized,
      );

      await storage.saveNotificationSettings([
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: false,
          minutesBefore: 0,
        ),
      ]);

      await scheduler.scheduleNotifications(
        location: testLocation,
        prayerTimes: [prayerTime],
      );

      expect(notificationService.scheduledNotifications.length, equals(0));
    });

    test('Schedules with offset correctly', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowNormalized = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
      );

      final prayerTime = PrayerTime(
        fajr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          5,
          30,
        ),
        sunrise: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          7,
          0,
        ),
        dhuhr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          13,
          15,
        ),
        asr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          16,
          30,
        ),
        maghrib: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          19,
          0,
        ),
        isha: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          20,
          30,
        ),
        date: tomorrowNormalized,
      );

      await storage.saveNotificationSettings([
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 15,
        ),
      ]);

      await scheduler.scheduleNotifications(
        location: testLocation,
        prayerTimes: [prayerTime],
      );

      expect(notificationService.scheduledNotifications.length, equals(1));
      final scheduled = notificationService.scheduledNotifications.first;
      expect(scheduled.scheduledTime.hour, equals(5));
      expect(scheduled.scheduledTime.minute, equals(15));
    });

    test('Does not schedule past prayer times', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayNormalized = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
      );

      final prayerTime = PrayerTime(
        fajr: DateTime(
          yesterdayNormalized.year,
          yesterdayNormalized.month,
          yesterdayNormalized.day,
          5,
          30,
        ),
        sunrise: DateTime(
          yesterdayNormalized.year,
          yesterdayNormalized.month,
          yesterdayNormalized.day,
          7,
          0,
        ),
        dhuhr: DateTime(
          yesterdayNormalized.year,
          yesterdayNormalized.month,
          yesterdayNormalized.day,
          13,
          15,
        ),
        asr: DateTime(
          yesterdayNormalized.year,
          yesterdayNormalized.month,
          yesterdayNormalized.day,
          16,
          30,
        ),
        maghrib: DateTime(
          yesterdayNormalized.year,
          yesterdayNormalized.month,
          yesterdayNormalized.day,
          19,
          0,
        ),
        isha: DateTime(
          yesterdayNormalized.year,
          yesterdayNormalized.month,
          yesterdayNormalized.day,
          20,
          30,
        ),
        date: yesterdayNormalized,
      );

      await storage.saveNotificationSettings([
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 0,
        ),
      ]);

      await scheduler.scheduleNotifications(
        location: testLocation,
        prayerTimes: [prayerTime],
      );

      expect(notificationService.scheduledNotifications.length, equals(0));
    });

    test('Cancels all notifications before scheduling', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowNormalized = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
      );

      final prayerTime = PrayerTime(
        fajr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          5,
          30,
        ),
        sunrise: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          7,
          0,
        ),
        dhuhr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          13,
          15,
        ),
        asr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          16,
          30,
        ),
        maghrib: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          19,
          0,
        ),
        isha: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          20,
          30,
        ),
        date: tomorrowNormalized,
      );

      await storage.saveNotificationSettings([
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 0,
        ),
      ]);

      notificationService.cancelAllCallCount = 0;

      await scheduler.scheduleNotifications(
        location: testLocation,
        prayerTimes: [prayerTime],
      );

      expect(notificationService.cancelAllCallCount, equals(1));
    });
  });

  group('Notification Scheduler - Duplicate Prevention', () {
    late MockLocalStorage storage;
    late MockNotificationService notificationService;
    late NotificationScheduler scheduler;
    late Location testLocation;

    setUp(() {
      storage = MockLocalStorage();
      notificationService = MockNotificationService();
      scheduler = NotificationScheduler(
        notificationService: notificationService,
        storage: storage,
      );
      testLocation = const Location(
        id: '1',
        province: 'Istanbul',
        district: 'Kadikoy',
        latitude: 40.9828,
        longitude: 29.0227,
      );
    });

    test('Prevents duplicate notifications for same prayer+offset', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowNormalized = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
      );

      final prayerTime = PrayerTime(
        fajr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          5,
          30,
        ),
        sunrise: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          7,
          0,
        ),
        dhuhr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          13,
          15,
        ),
        asr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          16,
          30,
        ),
        maghrib: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          19,
          0,
        ),
        isha: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          20,
          30,
        ),
        date: tomorrowNormalized,
      );

      await storage.saveNotificationSettings([
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 10,
        ),
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 10,
        ),
      ]);

      await scheduler.scheduleNotifications(
        location: testLocation,
        prayerTimes: [prayerTime],
      );

      expect(notificationService.scheduledNotifications.length, equals(1));
    });

    test('Allows different offsets for same prayer', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowNormalized = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
      );

      final prayerTime = PrayerTime(
        fajr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          5,
          30,
        ),
        sunrise: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          7,
          0,
        ),
        dhuhr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          13,
          15,
        ),
        asr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          16,
          30,
        ),
        maghrib: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          19,
          0,
        ),
        isha: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          20,
          30,
        ),
        date: tomorrowNormalized,
      );

      await storage.saveNotificationSettings([
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 0,
        ),
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 10,
        ),
      ]);

      await scheduler.scheduleNotifications(
        location: testLocation,
        prayerTimes: [prayerTime],
      );

      expect(notificationService.scheduledNotifications.length, equals(2));
    });

    test('Schedules for multiple prayers correctly', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowNormalized = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
      );

      final prayerTime = PrayerTime(
        fajr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          5,
          30,
        ),
        sunrise: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          7,
          0,
        ),
        dhuhr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          13,
          15,
        ),
        asr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          16,
          30,
        ),
        maghrib: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          19,
          0,
        ),
        isha: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          20,
          30,
        ),
        date: tomorrowNormalized,
      );

      await storage.saveNotificationSettings([
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 0,
        ),
        const NotificationSetting(
          prayerType: PrayerType.dhuhr,
          isActive: true,
          minutesBefore: 0,
        ),
        const NotificationSetting(
          prayerType: PrayerType.asr,
          isActive: true,
          minutesBefore: 0,
        ),
      ]);

      await scheduler.scheduleNotifications(
        location: testLocation,
        prayerTimes: [prayerTime],
      );

      expect(notificationService.scheduledNotifications.length, equals(3));
    });
  });

  group('Notification Scheduler - Permission Handling', () {
    late MockLocalStorage storage;
    late MockNotificationService notificationService;
    late NotificationScheduler scheduler;

    setUp(() {
      storage = MockLocalStorage();
      notificationService = MockNotificationService();
      scheduler = NotificationScheduler(
        notificationService: notificationService,
        storage: storage,
      );
    });

    test('Can check permission status', () async {
      notificationService.setPermissionGranted(true);
      expect(await scheduler.hasPermission(), isTrue);

      notificationService.setPermissionGranted(false);
      expect(await scheduler.hasPermission(), isFalse);
    });

    test('Can request permission', () async {
      notificationService.setPermissionGranted(true);

      final granted = await scheduler.requestPermission();
      expect(granted, isTrue);
    });

    test('Permission request can be denied', () async {
      notificationService.setPermissionGranted(false);

      final granted = await scheduler.requestPermission();
      expect(granted, isFalse);
    });
  });

  group('Notification Scheduler - Helper Methods', () {
    late MockLocalStorage storage;
    late MockNotificationService notificationService;
    late NotificationScheduler scheduler;

    setUp(() {
      storage = MockLocalStorage();
      notificationService = MockNotificationService();
      scheduler = NotificationScheduler(
        notificationService: notificationService,
        storage: storage,
      );
    });

    test('Can get pending notifications', () async {
      final pending = await scheduler.getPendingNotifications();
      expect(pending, isA<List<ScheduledNotification>>());
    });

    test('Can cancel all notifications', () async {
      await scheduler.cancelAllNotifications();
      expect(notificationService.scheduledNotifications, isEmpty);
    });

    test('Reschedule calls schedule with same parameters', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowNormalized = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
      );

      final prayerTime = PrayerTime(
        fajr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          5,
          30,
        ),
        sunrise: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          7,
          0,
        ),
        dhuhr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          13,
          15,
        ),
        asr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          16,
          30,
        ),
        maghrib: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          19,
          0,
        ),
        isha: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          20,
          30,
        ),
        date: tomorrowNormalized,
      );

      await storage.saveNotificationSettings([
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 0,
        ),
      ]);

      final location = const Location(
        id: '1',
        province: 'Istanbul',
        district: 'Kadikoy',
        latitude: 40.9828,
        longitude: 29.0227,
      );

      await scheduler.rescheduleNotifications(
        location: location,
        prayerTimes: [prayerTime],
      );

      expect(notificationService.scheduledNotifications.length, equals(1));
    });
  });

  group('Notification Integration - Settings and Scheduling', () {
    late MockLocalStorage storage;
    late MockNotificationService notificationService;
    late NotificationScheduler scheduler;
    late NotificationSettingsManager settingsManager;
    late Location testLocation;

    setUp(() {
      storage = MockLocalStorage();
      notificationService = MockNotificationService();
      scheduler = NotificationScheduler(
        notificationService: notificationService,
        storage: storage,
      );
      settingsManager = NotificationSettingsManager(storage: storage);
      testLocation = const Location(
        id: '1',
        province: 'Istanbul',
        district: 'Kadikoy',
        latitude: 40.9828,
        longitude: 29.0227,
      );
    });

    test('Changing settings requires rescheduling', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowNormalized = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
      );

      final prayerTime = PrayerTime(
        fajr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          5,
          30,
        ),
        sunrise: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          7,
          0,
        ),
        dhuhr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          13,
          15,
        ),
        asr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          16,
          30,
        ),
        maghrib: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          19,
          0,
        ),
        isha: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          20,
          30,
        ),
        date: tomorrowNormalized,
      );

      await settingsManager.createDefaultSettings();
      await settingsManager.disableAll();

      await scheduler.scheduleNotifications(
        location: testLocation,
        prayerTimes: [prayerTime],
      );

      expect(notificationService.scheduledNotifications.length, equals(0));

      await settingsManager.enableAll();

      await scheduler.rescheduleNotifications(
        location: testLocation,
        prayerTimes: [prayerTime],
      );

      expect(notificationService.scheduledNotifications.length, greaterThan(0));
    });

    test('Only active settings generate notifications', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowNormalized = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
      );

      final prayerTime = PrayerTime(
        fajr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          5,
          30,
        ),
        sunrise: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          7,
          0,
        ),
        dhuhr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          13,
          15,
        ),
        asr: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          16,
          30,
        ),
        maghrib: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          19,
          0,
        ),
        isha: DateTime(
          tomorrowNormalized.year,
          tomorrowNormalized.month,
          tomorrowNormalized.day,
          20,
          30,
        ),
        date: tomorrowNormalized,
      );

      await settingsManager.saveSettings([
        const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 0,
        ),
        const NotificationSetting(
          prayerType: PrayerType.dhuhr,
          isActive: false,
          minutesBefore: 0,
        ),
      ]);

      await scheduler.scheduleNotifications(
        location: testLocation,
        prayerTimes: [prayerTime],
      );

      expect(notificationService.scheduledNotifications.length, equals(1));

      final activeSettings = await settingsManager.getActiveSettings();
      expect(activeSettings.length, equals(1));
    });
  });
}
