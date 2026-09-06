import 'dart:async';

import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/mission_stop_event.dart';
import 'package:ezanvakti/core/interfaces/alarm_service.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/models/skipped_occurrence.dart';
import 'package:ezanvakti/features/alarms/data/native_alarm_service.dart';
import 'package:ezanvakti/features/alarms/domain/alarm_scheduler.dart';
import 'package:ezanvakti/features/notifications/domain/notification_scheduler.dart';
import 'package:ezanvakti/presentation/services/reminder_rescheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../support/fakes.dart';

class _MockAlarmService implements AlarmService {
  int cancelAllCount = 0;

  @override
  Future<void> cancelAllAlarms() async => cancelAllCount++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<MissionStopEvent> get missionStops => const Stream.empty();

  @override
  Future<List<MissionStopEvent>> consumeMissionEvents() async => const [];

  @override
  Future<void> beginMission(String alarmId) async {}

  @override
  Future<void> snoozeMission(String alarmId, int minutes) async {}

  @override
  Future<void> completeMission(String alarmId) async {}

  @override
  Future<void> abortMission(String alarmId) async {}
}

class _FailingNotificationService extends FakeNotificationService {
  final Object failure;
  final attempted = Completer<void>();

  _FailingNotificationService(this.failure);

  @override
  Future<void> scheduleNotification({
    required String id,
    required DateTime scheduledTime,
    required String title,
    required String body,
    String? soundId,
    bool silent = false,
    bool timeSensitive = true,
  }) async {
    attempted.complete();
    throw failure;
  }
}

class _DelayedNotificationService extends FakeNotificationService {
  final release = Completer<void>();

  @override
  Future<void> cancelAllNotifications() async {
    await release.future;
    await super.cancelAllNotifications();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const location = Location(
    id: 'loc-1',
    province: 'İstanbul',
    district: 'Kadıköy',
    latitude: 40.99,
    longitude: 29.03,
  );

  // Yarinin vakitleri; bugunun saatleri gecmis olabilecegi icin planlanmaz.
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final day = PrayerTime(
    date: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
    fajr: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 5, 0),
    sunrise: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 6, 30),
    dhuhr: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 13, 0),
    asr: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 16, 45),
    maghrib: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 20, 15),
    isha: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 21, 45),
  );

  Future<(ReminderRescheduler, FakeNotificationService, _MockAlarmService)>
  build() async {
    final storage = FakeStorage();
    await storage.init();
    await storage.saveNotificationSettings([
      const NotificationSetting(
        prayerType: PrayerType.dhuhr,
        isActive: true,
        minutesBefore: 0,
      ),
    ]);
    final notificationService = FakeNotificationService();
    final alarmService = _MockAlarmService();

    return (
      ReminderRescheduler(
        notificationScheduler: NotificationScheduler(
          notificationService: notificationService,
          storage: storage,
        ),
        alarmScheduler: AlarmScheduler(
          alarmService: alarmService,
          storage: storage,
        ),
      ),
      notificationService,
      alarmService,
    );
  }

  test('Vakit verisi varsa iki planlayici da calisir', () async {
    final (rescheduler, notifications, alarms) = await build();

    final done = await rescheduler.reschedule(
      location: location,
      prayerTimes: [day],
      skips: const {},
    );

    expect(done, isTrue);
    expect(notifications.scheduled, isNotEmpty);
    expect(alarms.cancelAllCount, 1);
  });

  test('Vakit verisi yoksa false doner ve hicbir seye dokunmaz', () async {
    final (rescheduler, notifications, alarms) = await build();

    final done = await rescheduler.reschedule(
      location: location,
      prayerTimes: const [],
      skips: const {},
    );

    // Gecici bir ag hatasi yuzunden kullanicinin mevcut bildirimleri
    // silinmemeli; iptal karari cagirana ait.
    expect(done, isFalse);
    expect(notifications.cancelAllCount, 0);
    expect(alarms.cancelAllCount, 0);
  });

  test('Konum yoksa false doner', () async {
    final (rescheduler, notifications, _) = await build();

    final done = await rescheduler.reschedule(
      location: null,
      prayerTimes: [day],
      skips: const {},
    );

    expect(done, isFalse);
    expect(notifications.cancelAllCount, 0);
  });

  test('skips planlayiciya gecer; atlanan bildirim planlanmaz', () async {
    final (rescheduler, notifications, _) = await build();
    final skip = SkippedOccurrence(
      kind: SkipKind.notification,
      reference: NotificationScheduler.notificationIdFor(
        date: day.date,
        pointIndex: PrayerType.dhuhr.index,
        minutesBefore: 0,
      ),
      fireAt: day.dhuhr,
    );

    await rescheduler.reschedule(
      location: location,
      prayerTimes: [day],
      skips: {skip},
    );

    expect(
      notifications.scheduled.map((n) => n.id),
      isNot(contains(skip.reference)),
    );
  });

  group('Planlama hatalarının izolasyonu', () {
    const channel = MethodChannel('com.ekrembulbul.ezanvakti/alarm');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final pendingAlarms = <String, int>{};

    Future<Object?> handleAlarmCall(MethodCall call) async {
      if (call.method == 'cancelAllAlarms') pendingAlarms.clear();
      if (call.method == 'scheduleAlarm') {
        final args = call.arguments as Map;
        pendingAlarms[args['id'] as String] = args['timeMillis'] as int;
      }
      return null;
    }

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      pendingAlarms.clear();
      messenger.setMockMethodCallHandler(channel, handleAlarmCall);
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    Future<ReminderRescheduler> buildNative(
      FakeNotificationService notifications,
    ) async {
      final storage = FakeStorage();
      await storage.init();
      await storage.saveNotificationSettings([
        const NotificationSetting(
          prayerType: PrayerType.dhuhr,
          isActive: true,
          minutesBefore: 0,
        ),
      ]);
      await storage.saveAlarm(
        const Alarm(
          id: 'sunrise',
          kind: AlarmKind.anchored,
          anchor: PrayerType.sunrise,
          offsetMinutes: -30,
        ),
      );
      return ReminderRescheduler(
        notificationScheduler: NotificationScheduler(
          notificationService: notifications,
          storage: storage,
        ),
        alarmScheduler: AlarmScheduler(
          alarmService: NativeAlarmService(),
          storage: storage,
        ),
      );
    }

    test(
      'Bildirim hatasına rağmen güneş alarmı güncel vakitle yeniden kurulur',
      () async {
        final failure = StateError('notification schedule failed');
        final rescheduler = await buildNative(
          _FailingNotificationService(failure),
        );
        pendingAlarms['sunrise'] = DateTime(
          day.date.year,
          day.date.month,
          day.date.day,
          6,
          5,
        ).millisecondsSinceEpoch;

        await expectLater(
          rescheduler.reschedule(
            location: location,
            prayerTimes: [day],
            skips: const {},
          ),
          throwsA(same(failure)),
        );

        expect(
          pendingAlarms['sunrise'],
          DateTime(
            day.date.year,
            day.date.month,
            day.date.day,
            6,
          ).millisecondsSinceEpoch,
        );
      },
    );

    test('Hata, diğer planlama tamamlanmadan çağırana dönmez', () async {
      final failure = StateError('notification schedule failed');
      final notifications = _FailingNotificationService(failure);
      final rescheduler = await buildNative(notifications);
      final releaseAlarm = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'scheduleAlarm') await releaseAlarm.future;
        return handleAlarmCall(call);
      });
      var completed = false;
      final outcome = expectLater(
        rescheduler.reschedule(
          location: location,
          prayerTimes: [day],
          skips: const {},
        ),
        throwsA(same(failure)),
      ).whenComplete(() => completed = true);

      try {
        await notifications.attempted.future;
        await pumpEventQueue();
        expect(completed, isFalse);
      } finally {
        releaseAlarm.complete();
        await outcome;
      }
      expect(pendingAlarms, contains('sunrise'));
    });

    test('Bekleyen bildirim planlaması alarmı geciktirmez', () async {
      final notifications = _DelayedNotificationService();
      final rescheduler = await buildNative(notifications);
      var completed = false;
      final outcome = rescheduler
          .reschedule(location: location, prayerTimes: [day], skips: const {})
          .whenComplete(() => completed = true);

      try {
        await pumpEventQueue();
        expect(pendingAlarms, contains('sunrise'));
        expect(completed, isFalse);
      } finally {
        notifications.release.complete();
        await outcome;
      }
      expect(notifications.scheduled, hasLength(1));
    });

    test('İki planlamanın hatası da stack trace ile loglanır', () async {
      final notificationFailure = StateError('notification schedule failed');
      final rescheduler = await buildNative(
        _FailingNotificationService(notificationFailure),
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'cancelAllAlarms') {
          throw PlatformException(code: 'alarm_cancel_failed');
        }
        return handleAlarmCall(call);
      });
      final events = <LogEvent>[];
      void record(LogEvent event) {
        if (event.error != null) events.add(event);
      }

      Logger.addLogListener(record);
      addTearDown(() => Logger.removeLogListener(record));
      final alarmFailure = isA<PlatformException>().having(
        (error) => error.code,
        'code',
        'alarm_cancel_failed',
      );

      await expectLater(
        rescheduler.reschedule(
          location: location,
          prayerTimes: [day],
          skips: const {},
        ),
        throwsA(anyOf(same(notificationFailure), alarmFailure)),
      );

      expect(
        events.map((event) => event.error),
        unorderedMatches([same(notificationFailure), alarmFailure]),
      );
      expect(events.every((event) => event.stackTrace != null), isTrue);
    });
  });
}
