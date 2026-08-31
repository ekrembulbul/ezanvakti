import 'package:ezanvakti/core/interfaces/alarm_service.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/alarm_theme.dart';
import 'package:ezanvakti/core/models/mission_stop_event.dart';
import 'package:ezanvakti/core/models/notification_setting.dart' show PrayerType;
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/models/skipped_occurrence.dart';
import 'package:ezanvakti/features/alarms/domain/alarm_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

/// scheduleAlarm cagrilarini butun argumanlariyla kaydeden servis.
class _RecordingAlarmService implements AlarmService {
  final List<({String id, DateTime time, List<int> repeatWeekdays, bool missionEnabled})>
  calls = [];

  @override
  Future<void> scheduleAlarm({
    required String id,
    required DateTime scheduledTime,
    required String label,
    required String soundId,
    required bool vibrate,
    required bool snoozeEnabled,
    required int snoozeMinutes,
    required AlarmTheme theme,
    required AlarmMission mission,
    required int missionLevel,
    required Map<String, dynamic> chainConfig,
    List<int> repeatWeekdays = const [],
  }) async {
    calls.add((
      id: id,
      time: scheduledTime,
      repeatWeekdays: repeatWeekdays,
      missionEnabled: mission.requiresGate,
    ));
  }

  @override
  Future<void> cancelAllAlarms() async {}

  @override
  Stream<MissionStopEvent> get missionStops => const Stream.empty();

  @override
  Future<List<MissionStopEvent>> consumeMissionEvents() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StorageWithAlarms implements LocalStorage {
  final List<Alarm> alarms;

  _StorageWithAlarms(this.alarms);

  @override
  Future<List<Alarm>> getAlarms() async => alarms;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  AlarmScheduler schedulerWith(_RecordingAlarmService service, List<Alarm> alarms) =>
      AlarmScheduler(alarmService: service, storage: _StorageWithAlarms(alarms));

  PrayerTime prayerTimeFor(DateTime day) {
    DateTime at(int hour, int minute) =>
        DateTime(day.year, day.month, day.day, hour, minute);
    return PrayerTime(
      date: DateTime(day.year, day.month, day.day),
      fajr: at(5, 0),
      sunrise: at(6, 30),
      dhuhr: at(13, 0),
      asr: at(16, 30),
      maghrib: at(19, 45),
      isha: at(21, 15),
    );
  }

  final now = DateTime.now();
  final week = [for (var i = 0; i < 9; i++) prayerTimeFor(now.add(Duration(days: i)))];

  test('sabit tekrarli alarm secili gunlerle native tekrara gecer', () async {
    final service = _RecordingAlarmService();
    const alarm = Alarm(
      id: 'a1',
      kind: AlarmKind.fixed,
      hour: 6,
      minute: 30,
      weekdays: {1, 5},
    );
    await schedulerWith(service, [alarm]).scheduleAlarms(prayerTimes: const []);
    expect(service.calls.single.repeatWeekdays, [1, 5]);
  });

  test('sabit her-gun alarmi 1..7 ile native tekrara gecer', () async {
    final service = _RecordingAlarmService();
    const alarm = Alarm(id: 'a1', kind: AlarmKind.fixed, hour: 6, minute: 30);
    await schedulerWith(service, [alarm]).scheduleAlarms(prayerTimes: const []);
    expect(service.calls.single.repeatWeekdays, [1, 2, 3, 4, 5, 6, 7]);
  });

  test('tek seferlik atlama varken sabit alarm tek seferlik yola duser', () async {
    final service = _RecordingAlarmService();
    const alarm = Alarm(id: 'a1', kind: AlarmKind.fixed, hour: 6, minute: 30);
    final fire = AlarmScheduler.computeNextFire(
      alarm: alarm,
      now: now,
      prayerTimesByDate: const {},
    )!;
    await schedulerWith(service, [alarm]).scheduleAlarms(
      prayerTimes: const [],
      skips: {
        SkippedOccurrence(kind: SkipKind.alarm, reference: 'a1', fireAt: fire),
      },
    );
    expect(service.calls.single.repeatWeekdays, isEmpty);
  });

  test('cipali tekrarli alarm 7 gunluk dizi olarak kurulur', () async {
    final service = _RecordingAlarmService();
    const alarm = Alarm(
      id: 'a1',
      kind: AlarmKind.anchored,
      anchor: PrayerType.fajr,
      offsetMinutes: -30,
      mission: AlarmMission.math,
    );
    await schedulerWith(service, [alarm]).scheduleAlarms(prayerTimes: week);
    // Birincil calis eksiz: gorev oturumu ve skip kayitlari alarm.id ile
    // eslesiyor; ek tasisaydi gorev ekrani alarmi bulamazdi.
    expect(
      service.calls.map((c) => c.id).toList(),
      ['a1', 'a1#d1', 'a1#d2', 'a1#d3', 'a1#d4', 'a1#d5', 'a1#d6'],
    );
    // Gorev zinciri yalnizca en yakin calisa kurulur; sonraki gunler her
    // yeniden planlamada birincillesir.
    expect(service.calls.first.missionEnabled, isTrue);
    expect(service.calls.skip(1).every((c) => !c.missionEnabled), isTrue);
    final times = service.calls.map((c) => c.time).toList();
    expect(times, orderedEquals([...times]..sort()));
  });

  test('computeNextFires atlanan gunu diziden cikarir', () {
    const alarm = Alarm(
      id: 'a1',
      kind: AlarmKind.anchored,
      anchor: PrayerType.fajr,
      offsetMinutes: 0,
    );
    final byDate = {
      for (final pt in week) DateTime(pt.date.year, pt.date.month, pt.date.day): pt,
    };
    final all = AlarmScheduler.computeNextFires(
      alarm: alarm,
      now: now,
      prayerTimesByDate: byDate,
    );
    expect(all.length, 7);
    final skipped = AlarmScheduler.computeNextFires(
      alarm: alarm,
      now: now,
      prayerTimesByDate: byDate,
      skips: {
        SkippedOccurrence(kind: SkipKind.alarm, reference: 'a1', fireAt: all[1]),
      },
    );
    expect(skipped, isNot(contains(all[1])));
    expect(skipped.first, all.first);
  });

  test('cipali alarm relative olamaz, tek seferlik kalir', () async {
    final service = _RecordingAlarmService();
    const alarm = Alarm(
      id: 'a1',
      kind: AlarmKind.anchored,
      anchor: PrayerType.fajr,
      offsetMinutes: -30,
    );
    await schedulerWith(service, [alarm]).scheduleAlarms(prayerTimes: week);
    expect(service.calls, isNotEmpty);
    expect(service.calls.every((c) => c.repeatWeekdays.isEmpty), isTrue);
  });
}
