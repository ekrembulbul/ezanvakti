import 'package:ezanvakti/core/errors/prayer_times_errors.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/interfaces/notification_service.dart';
import 'package:ezanvakti/core/interfaces/prayer_time_provider.dart';
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/appearance_settings.dart';
import 'package:ezanvakti/core/models/calculation_settings.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/features/location/domain/location_repository.dart';
import 'package:ezanvakti/features/location/domain/location_service.dart';
import 'package:ezanvakti/features/notifications/domain/notification_scheduler.dart';
import 'package:ezanvakti/features/prayer_times/domain/prayer_times_repository.dart';
import 'package:ezanvakti/presentation/widgets/notifications/permission_warning_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/theme_harness.dart';

/// `docs/PLAN_CHECKLIST.md`'deki MVP kabul kriterlerinin uctan uca karsiligi.
///
/// Diger test dosyalari katmanlari tek tek dogruluyor; buradaki dort senaryo
/// katmanlari **birlestirip** kullanicinin gordugu davranisi kaniti sayiyor:
/// online ilk yukleme, ag kesildiginde onbellege dusme, konum degisimi ve
/// bildirim izni verilmemis hali.
void main() {
  const istanbul = Location(
    id: 'loc-istanbul',
    province: 'İstanbul',
    district: 'Kadıköy',
    latitude: 40.99,
    longitude: 29.03,
  );
  const ankara = Location(
    id: 'loc-ankara',
    province: 'Ankara',
    district: 'Çankaya',
    latitude: 39.92,
    longitude: 32.85,
  );

  /// Senaryolarin ortak kurulumu: bos depo, 30 gunluk veri uretebilen saglayici
  /// ve cagrilari sayan bildirim servisi.
  ({
    _FakeStorage storage,
    _FakeProvider provider,
    _FakeNotificationService notifications,
    PrayerTimesRepository prayerTimes,
  })
  buildStack() {
    final storage = _FakeStorage();
    final provider = _FakeProvider();
    return (
      storage: storage,
      provider: provider,
      notifications: _FakeNotificationService(),
      prayerTimes: PrayerTimesRepository(provider: provider, storage: storage),
    );
  }

  group('MVP kabul — online', () {
    test('Konum secilince bugunun vakitleri gorulebiliyor', () async {
      final stack = buildStack();
      await stack.storage.init();
      await stack.storage.saveActiveLocation(istanbul);

      final today = _atMidnight(DateTime.now());
      final times = await stack.prayerTimes.getPrayerTimes(
        location: istanbul,
        startDate: today,
        endDate: today.add(const Duration(days: 6)),
      );

      expect(times, hasLength(7));
      expect(
        stack.provider.fetchCount,
        1,
        reason: 'Onbellek bostu, ag denendi',
      );

      // Bugunun vakti tutarli sirada ve artik onbellekte.
      final first = times.first;
      expect(first.fajr.isBefore(first.dhuhr), isTrue);
      expect(first.dhuhr.isBefore(first.isha), isTrue);
      expect(
        await stack.storage.getDailyPrayerTime(
          locationId: istanbul.id,
          date: today,
        ),
        isNotNull,
      );
    });

    test('Aktif bildirim ayarlari icin bildirim planlaniyor', () async {
      final stack = buildStack();
      await stack.storage.init();
      await stack.storage.saveNotificationSettings(const [
        NotificationSetting(prayerType: PrayerType.dhuhr, isActive: true),
        NotificationSetting(prayerType: PrayerType.asr, isActive: false),
      ]);

      final today = _atMidnight(DateTime.now());
      final times = await stack.prayerTimes.getPrayerTimes(
        location: istanbul,
        startDate: today,
        endDate: today.add(const Duration(days: 6)),
      );

      final scheduler = NotificationScheduler(
        notificationService: stack.notifications,
        storage: stack.storage,
      );
      await scheduler.scheduleNotifications(
        location: istanbul,
        prayerTimes: times,
      );

      // Bildirim id'si sayisal; hangi vakit icin planlandigi ancak zamandan
      // okunur. Ogle 13:15, kapali olan Ikindi 17:09.
      expect(stack.notifications.scheduled, isNotEmpty);
      expect(
        stack.notifications.scheduled.every(
          (n) => n.scheduledTime.hour == 13 && n.scheduledTime.minute == 15,
        ),
        isTrue,
        reason: 'Yalnizca aktif ayar planlanmali, kapali olan degil',
      );
    });
  });

  group('MVP kabul — offline', () {
    test('Ag kesilince onbellekteki vakitler gosteriliyor', () async {
      final stack = buildStack();
      await stack.storage.init();

      final today = _atMidnight(DateTime.now());
      final end = today.add(const Duration(days: 6));

      // Once online: onbellek dolar.
      await stack.prayerTimes.getPrayerTimes(
        location: istanbul,
        startDate: today,
        endDate: end,
      );
      expect(stack.provider.fetchCount, 1);

      // Sonra ag kesilir. forceRefresh ile ag zorlanir ki fallback yolu
      // gercekten calissin; onbellek dolu oldugu icin istisna kullaniciya
      // yansimamali.
      stack.provider.failWith = NetworkException('Baglanti yok');
      final offline = await stack.prayerTimes.getPrayerTimes(
        location: istanbul,
        startDate: today,
        endDate: end,
        forceRefresh: true,
      );

      expect(offline, hasLength(7));
      expect(stack.provider.fetchCount, 2, reason: 'Once ag denenmeli');
    });

    test('Onbellek de bossa hata kullaniciya iletiliyor', () async {
      final stack = buildStack();
      await stack.storage.init();
      stack.provider.failWith = NetworkException('Baglanti yok');

      final today = _atMidnight(DateTime.now());

      expect(
        () => stack.prayerTimes.getPrayerTimes(
          location: istanbul,
          startDate: today,
          endDate: today,
        ),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('MVP kabul — konum degisimi', () {
    test('Konum degisince aktif konum ve bildirimler guncelleniyor', () async {
      final stack = buildStack();
      await stack.storage.init();
      await stack.storage.saveActiveLocation(istanbul);
      await stack.storage.saveNotificationSettings(const [
        NotificationSetting(prayerType: PrayerType.dhuhr, isActive: true),
      ]);

      final today = _atMidnight(DateTime.now());
      final end = today.add(const Duration(days: 6));

      final istanbulTimes = await stack.prayerTimes.getPrayerTimes(
        location: istanbul,
        startDate: today,
        endDate: end,
      );
      final scheduler = NotificationScheduler(
        notificationService: stack.notifications,
        storage: stack.storage,
      );
      await scheduler.scheduleNotifications(
        location: istanbul,
        prayerTimes: istanbulTimes,
      );
      expect(stack.notifications.scheduled, isNotEmpty);

      final locationService = LocationService(
        locationRepository: LocationRepository(storage: stack.storage),
        prayerTimesRepository: stack.prayerTimes,
        notificationService: stack.notifications,
      );
      await locationService.changeLocation(ankara);

      expect((await stack.storage.getActiveLocation())?.id, ankara.id);
      expect(
        stack.notifications.scheduled,
        isEmpty,
        reason: 'Eski konumun bekleyen bildirimleri iptal edilmeli',
      );

      // Yeni konumun vakitleriyle yeniden planlanabiliyor.
      final ankaraTimes = await stack.prayerTimes.getPrayerTimes(
        location: ankara,
        startDate: today,
        endDate: end,
      );
      await scheduler.scheduleNotifications(
        location: ankara,
        prayerTimes: ankaraTimes,
      );
      expect(stack.notifications.scheduled, isNotEmpty);
    });

    test('Ayni konuma gecis gereksiz iptal tetiklemiyor', () async {
      final stack = buildStack();
      await stack.storage.init();
      await stack.storage.saveActiveLocation(istanbul);

      final locationService = LocationService(
        locationRepository: LocationRepository(storage: stack.storage),
        prayerTimesRepository: stack.prayerTimes,
        notificationService: stack.notifications,
      );
      await locationService.changeLocation(istanbul);

      expect(stack.notifications.cancelAllCount, 0);
    });
  });

  group('MVP kabul — bildirim izni yok', () {
    testWidgets(
      'Izin yoksa kullanici uyarilir ve izin istemeye yonlendirilir',
      (tester) async {
        final notifications = _FakeNotificationService()
          ..permissionGranted = false;
        bool? reportedResult;

        await tester.pumpWidget(
          wrapWithTheme(
            PermissionWarningCard(
              onRequestPermission: notifications.requestPermission,
              onPermissionGranted: (granted) => reportedResult = granted,
            ),
          ),
        );

        expect(find.byKey(const Key('permission_warning')), findsOneWidget);
        expect(
          find.text('Bildirim almak için izin vermeniz gerekiyor.'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('request_permission_button')));
        await tester.pumpAndSettle();

        expect(notifications.permissionRequestCount, 1);
        expect(
          reportedResult,
          isFalse,
          reason: 'Izin reddedilince ekran bunu ogrenmeli, sessiz kalmamali',
        );
      },
    );

    test('Izin reddedilmis olsa da eski bildirimler temizleniyor', () async {
      final stack = buildStack();
      await stack.storage.init();
      stack.notifications.permissionGranted = false;

      // Ayar listesi bos: planlanacak bildirim yok ama eskiler iptal edilmeli.
      final scheduler = NotificationScheduler(
        notificationService: stack.notifications,
        storage: stack.storage,
      );
      await scheduler.scheduleNotifications(
        location: istanbul,
        prayerTimes: const [],
      );

      expect(stack.notifications.scheduled, isEmpty);
      expect(stack.notifications.cancelAllCount, 1);
    });
  });
}

DateTime _atMidnight(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Verilen gun icin sabit saatlerde bir [PrayerTime] uretir.
PrayerTime _prayerTimeFor(DateTime day) {
  DateTime at(int hour, int minute) =>
      DateTime(day.year, day.month, day.day, hour, minute);
  return PrayerTime(
    date: _atMidnight(day),
    fajr: at(4, 11),
    sunrise: at(5, 55),
    dhuhr: at(13, 15),
    asr: at(17, 9),
    maghrib: at(20, 25),
    isha: at(22, 1),
  );
}

/// Istege bagli olarak hata firlatabilen, cagri sayan saglayici.
class _FakeProvider implements PrayerTimeProvider {
  int fetchCount = 0;
  Exception? failWith;

  @override
  String get providerName => 'fake';

  @override
  Future<List<PrayerTime>> fetchPrayerTimes({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    fetchCount++;
    final failure = failWith;
    if (failure != null) throw failure;

    final days = endDate.difference(startDate).inDays;
    return List.generate(
      days + 1,
      (i) => _prayerTimeFor(startDate.add(Duration(days: i))),
    );
  }

  @override
  Future<PrayerTime?> fetchDailyPrayerTime({
    required Location location,
    required DateTime date,
  }) async {
    fetchCount++;
    final failure = failWith;
    if (failure != null) throw failure;
    return _prayerTimeFor(date);
  }
}

/// Bellekte tutan depo. Vakitler konum + gun anahtariyla saklanir.
class _FakeStorage implements LocalStorage {
  final Map<String, Map<String, PrayerTime>> _times = {};
  final List<Location> _locations = [];
  final List<Alarm> _alarms = [];
  List<NotificationSetting> _notificationSettings = [];
  Location? _activeLocation;
  DateTime? _lastUpdate;
  CalculationSettings _calculationSettings = CalculationSettings.defaults;
  AppearanceSettings _appearanceSettings = const AppearanceSettings();
  bool _defaultsInitialized = false;

  static String _dayKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  @override
  Future<void> init() async {}

  @override
  Future<void> savePrayerTimes(
    List<PrayerTime> prayerTimes,
    String locationId,
  ) async {
    final bucket = _times.putIfAbsent(locationId, () => {});
    for (final time in prayerTimes) {
      bucket[_dayKey(time.date)] = time;
    }
  }

  @override
  Future<List<PrayerTime>> getPrayerTimes({
    required String locationId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final bucket = _times[locationId];
    if (bucket == null) return [];
    return bucket.values
        .where(
          (t) =>
              !t.date.isBefore(_atMidnight(startDate)) &&
              !t.date.isAfter(_atMidnight(endDate)),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<PrayerTime?> getDailyPrayerTime({
    required String locationId,
    required DateTime date,
  }) async {
    return _times[locationId]?[_dayKey(date)];
  }

  @override
  Future<void> deleteOldPrayerTimes(DateTime cutoffDate) async {
    for (final bucket in _times.values) {
      bucket.removeWhere((_, time) => time.date.isBefore(cutoffDate));
    }
  }

  @override
  Future<void> deletePrayerTimesForLocation(String locationId) async {
    _times.remove(locationId);
  }

  @override
  Future<void> deleteAllPrayerTimes() async => _times.clear();

  @override
  Future<CalculationSettings> getCalculationSettings() async =>
      _calculationSettings;

  @override
  Future<void> saveCalculationSettings(CalculationSettings settings) async {
    _calculationSettings = settings;
  }

  @override
  Future<AppearanceSettings> getAppearanceSettings() async =>
      _appearanceSettings;

  @override
  Future<void> saveAppearanceSettings(AppearanceSettings settings) async {
    _appearanceSettings = settings;
  }

  @override
  Future<void> saveActiveLocation(Location location) async {
    _activeLocation = location;
    if (!_locations.any((l) => l.id == location.id)) _locations.add(location);
  }

  @override
  Future<Location?> getActiveLocation() async => _activeLocation;

  @override
  Future<List<Location>> getSavedLocations() async => List.of(_locations);

  @override
  Future<void> saveLocation(Location location) async {
    _locations.add(location);
  }

  @override
  Future<void> updateLocation(Location location) async {
    final index = _locations.indexWhere((l) => l.id == location.id);
    if (index >= 0) _locations[index] = location;
    if (_activeLocation?.id == location.id) _activeLocation = location;
  }

  @override
  Future<void> deleteLocation(String locationId) async {
    _locations.removeWhere((l) => l.id == locationId);
  }

  @override
  Future<void> saveNotificationSettings(
    List<NotificationSetting> settings,
  ) async {
    _notificationSettings = List.of(settings);
  }

  @override
  Future<List<NotificationSetting>> getNotificationSettings() async =>
      List.of(_notificationSettings);

  @override
  Future<void> addNotificationSetting(NotificationSetting setting) async {
    _notificationSettings.add(setting);
  }

  @override
  Future<void> deleteNotificationSetting({
    required PrayerType prayerType,
    required int minutesBefore,
  }) async {
    _notificationSettings.removeWhere(
      (s) => s.prayerType == prayerType && s.minutesBefore == minutesBefore,
    );
  }

  @override
  Future<bool> isNotificationDefaultsInitialized() async =>
      _defaultsInitialized;

  @override
  Future<void> markNotificationDefaultsInitialized() async {
    _defaultsInitialized = true;
  }

  @override
  Future<void> saveLastUpdateTime(DateTime time) async => _lastUpdate = time;

  @override
  Future<DateTime?> getLastUpdateTime() async => _lastUpdate;

  @override
  Future<List<Alarm>> getAlarms() async => List.of(_alarms);

  @override
  Future<void> saveAlarm(Alarm alarm) async {
    final index = _alarms.indexWhere((a) => a.id == alarm.id);
    if (index >= 0) {
      _alarms[index] = alarm;
    } else {
      _alarms.add(alarm);
    }
  }

  @override
  Future<void> deleteAlarm(String id) async {
    _alarms.removeWhere((a) => a.id == id);
  }
}

/// Planlanan bildirimleri ve izin cagrilarini kaydeden servis.
class _FakeNotificationService implements NotificationService {
  final List<ScheduledNotification> scheduled = [];
  int cancelAllCount = 0;
  int permissionRequestCount = 0;
  bool permissionGranted = true;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequestCount++;
    return permissionGranted;
  }

  @override
  Future<bool> isPermissionGranted() async => permissionGranted;

  @override
  Future<void> scheduleNotification({
    required String id,
    required DateTime scheduledTime,
    required String title,
    required String body,
  }) async {
    scheduled.add(
      ScheduledNotification(
        id: id,
        scheduledTime: scheduledTime,
        // Kimlik "<prayer>_<offset>_<gun>" bicimindedir; testler id uzerinden
        // dogruladigi icin burada varsayilan degerler yeterli.
        prayerType: PrayerType.fajr,
        minutesBefore: 0,
      ),
    );
  }

  @override
  Future<void> cancelNotification(String id) async {
    scheduled.removeWhere((n) => n.id == id);
  }

  @override
  Future<void> cancelAllNotifications() async {
    cancelAllCount++;
    scheduled.clear();
  }

  @override
  Future<List<ScheduledNotification>> getPendingNotifications() async =>
      List.of(scheduled);

  @override
  Future<void> openExactAlarmSettings() async {}
}
