import 'package:ezanvakti/core/models/mission_stop_event.dart';
import 'package:ezanvakti/core/interfaces/alarm_service.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/models/skipped_occurrence.dart';
import 'package:ezanvakti/features/alarms/domain/alarm_scheduler.dart';
import 'package:ezanvakti/features/notifications/domain/notification_scheduler.dart';
import 'package:ezanvakti/presentation/services/reminder_rescheduler.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
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
}
