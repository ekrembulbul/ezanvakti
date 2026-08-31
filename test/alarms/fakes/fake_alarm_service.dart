import 'dart:async';

import 'package:ezanvakti/core/interfaces/alarm_service.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/alarm_theme.dart';
import 'package:ezanvakti/core/models/mission_stop_event.dart';

/// Cagrilari kaydeden bellek-ici [AlarmService].
class FakeAlarmService implements AlarmService {
  List<MissionStopEvent> pendingEvents = [];
  final _stops = StreamController<MissionStopEvent>.broadcast();

  @override
  Stream<MissionStopEvent> get missionStops => _stops.stream;

  final List<String> begun = [];
  final List<String> completed = [];
  final List<String> aborted = [];

  /// Yeniden planlama izi: `cancelAllAlarms` ve `scheduleAlarm` cagrilari
  /// sirayla. Gorev bitince alarmlarin yeniden kurulup kurulmadigini
  /// dogrulamak icin.
  final List<String> scheduled = [];
  int cancelAllCount = 0;

  @override
  Future<List<MissionStopEvent>> consumeMissionEvents() async {
    final events = pendingEvents;
    pendingEvents = [];
    return events;
  }

  @override
  Future<void> beginMission(String alarmId) async => begun.add(alarmId);

  final List<({String id, int minutes})> snoozed = [];

  @override
  Future<void> snoozeMission(String alarmId, int minutes) async =>
      snoozed.add((id: alarmId, minutes: minutes));

  @override
  Future<void> completeMission(String alarmId) async => completed.add(alarmId);

  @override
  Future<void> abortMission(String alarmId) async => aborted.add(alarmId);

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> isPermissionGranted() async => true;

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
  }) async => scheduled.add(id);

  @override
  Future<void> cancelAlarm(String id) async {}

  @override
  Future<void> cancelAllAlarms() async => cancelAllCount++;

  @override
  Future<String?> importCustomSound(String sourcePath) async => null;
}
