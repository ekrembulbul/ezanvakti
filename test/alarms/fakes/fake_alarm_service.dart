import 'dart:async';

import 'package:ezanvakti/core/config/mission_tuning.dart';
import 'package:ezanvakti/core/interfaces/alarm_service.dart';
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/alarm_plan.dart';
import 'package:ezanvakti/core/models/alarm_theme.dart';
import 'package:ezanvakti/core/models/mission_session.dart';
import 'package:ezanvakti/core/models/mission_stop_event.dart';

/// Native contract fake: snapshots remain readable after an event or UI failure.
class FakeAlarmService implements AlarmService {
  FakeAlarmService({this.alarmDefinitions});
  final Future<List<Alarm>> Function()? alarmDefinitions;
  List<MissionStopEvent> pendingEvents = [];
  final _processedEvents = <String>{};
  final _sessions = <String, MissionSession>{};
  final _definitions = <String, Alarm>{};
  final _accepted = <String, AlarmPlanEntry>{};
  Set<String>? _enabledRoots;
  final _stops = StreamController<MissionStopEvent>.broadcast();
  final plans = <AlarmPlan>[];
  Object? snapshotError;

  @override
  Stream<MissionStopEvent> get missionStops => _stops.stream;
  final begun = <String>[];
  final completed = <String>[];
  final aborted = <String>[];
  final scheduled = <String>[];
  final cancelled = <String>[];
  int cancelAllCount = 0;
  final snoozed = <({String id, int minutes})>[];
  Object? snoozeError;

  Future<void> seedSession(MissionSession? session) async {
    if (session == null) {
      _sessions.clear();
    } else {
      _sessions[session.alarmId] = session;
    }
  }

  Future<void> _syncEvents() async {
    if (alarmDefinitions != null) {
      for (final alarm in await alarmDefinitions!()) {
        _definitions[alarm.id] = alarm;
      }
    }
    for (final event in pendingEvents) {
      final key =
          '${event.alarmId}|${event.stoppedAt.toIso8601String()}|${event.chainStopped}';
      if (!_processedEvents.add(key)) continue;
      if (_enabledRoots != null && !_enabledRoots!.contains(event.alarmId)) {
        continue;
      }
      final existing = _sessions[event.alarmId];
      final same =
          existing != null &&
          (event.firedAt == null || existing.firedAt == event.firedAt);
      final fire = event.firedAt ?? (same ? existing.firedAt : event.stoppedAt);
      _sessions[event.alarmId] = MissionSession(
        alarmId: event.alarmId,
        firedAt: fire,
        stoppedAt: event.stoppedAt,
        snoozeUsed: event.snoozeUsed ?? (same ? existing.snoozeUsed : 0),
        rearmCount: event.rearmCount ?? (same ? existing.rearmCount + 1 : 0),
        completedAt: event.chainStopped ? event.stoppedAt : null,
        chainDeadlineAt:
            _definitions[event.alarmId]?.mission.requiresGate == true
            ? fire.add(
                const Duration(minutes: MissionTuning.chainDeadlineMinutes),
              )
            : null,
      );
    }
  }

  @override
  Future<List<MissionSession>> getMissionSessions() async {
    if (snapshotError != null) throw snapshotError!;
    await _syncEvents();
    return _sessions.values.where((s) => s.isPending).toList()..sort((a, b) {
      final time = a.firedAt.compareTo(b.firedAt);
      return time != 0 ? time : a.alarmId.compareTo(b.alarmId);
    });
  }

  @override
  Future<Map<String, String>> reconcileAlarms(AlarmPlan plan) async {
    plans.add(plan);
    _enabledRoots = Set.of(plan.enabledAlarmIds);
    _sessions.removeWhere((id, _) => !plan.enabledAlarmIds.contains(id));
    final failures = <String, String>{};
    for (final record in plan.records) {
      _definitions[record.alarm.id] = record.alarm;
      try {
        await scheduleAlarm(
          id: record.id,
          scheduledTime: record.scheduledTime,
          label: record.alarm.label,
          soundId: record.alarm.soundId,
          vibrate: record.alarm.vibrate,
          snoozeEnabled: record.alarm.snoozeEnabled,
          snoozeMinutes: record.alarm.snoozeMinutes,
          theme: record.theme,
          mission: record.alarm.mission,
          missionLevel: record.alarm.missionLevel,
          chainConfig: record.chainConfig,
          repeatWeekdays: record.repeatWeekdays,
        );
        _accepted[record.id] = record;
      } catch (error) {
        failures[record.alarm.id] = error.toString();
      }
    }
    final desired = plan.records.map((r) => r.id).toSet();
    _accepted.removeWhere(
      (id, record) =>
          !plan.enabledAlarmIds.contains(record.alarm.id) ||
          (!desired.contains(id) &&
              !plan.preserveAlarmIds.contains(record.alarm.id) &&
              !failures.containsKey(record.alarm.id)),
    );
    return failures;
  }

  MissionSession? _matching(String id, DateTime? firedAt) {
    final session = _sessions[id];
    if (firedAt != null && session?.firedAt != firedAt) {
      throw StateError('stale occurrence');
    }
    return session;
  }

  @override
  Future<void> beginMission(String alarmId, {DateTime? firedAt}) async {
    await _syncEvents();
    begun.add(alarmId);
    final session = _matching(alarmId, firedAt);
    if (session == null) return;
    final now = DateTime.now();
    if (session.deadlineAt?.isAfter(now) == true) return;
    final mission = _definitions[alarmId]?.mission ?? AlarmMission.math;
    var deadline = now.add(
      Duration(seconds: MissionTuning.timeoutSecondsFor(mission)),
    );
    if (session.chainDeadlineAt != null &&
        deadline.isAfter(session.chainDeadlineAt!)) {
      deadline = session.chainDeadlineAt!;
    }
    _sessions[alarmId] = session.copyWith(
      deadlineAt: deadline,
      clearSnoozedUntil: true,
    );
  }

  @override
  Future<void> snoozeMission(
    String alarmId,
    int minutes, {
    DateTime? firedAt,
  }) async {
    if (snoozeError != null) throw snoozeError!;
    await _syncEvents();
    final session = _matching(alarmId, firedAt);
    if (session == null) return;
    if (session.snoozedUntil?.isAfter(DateTime.now()) == true) return;
    snoozed.add((id: alarmId, minutes: minutes));
    _sessions[alarmId] = session.copyWith(
      snoozeUsed: session.snoozeUsed + 1,
      clearDeadline: true,
      snoozedUntil: DateTime.now().add(Duration(minutes: minutes)),
    );
  }

  @override
  Future<void> completeMission(String alarmId, {DateTime? firedAt}) async {
    await _syncEvents();
    _matching(alarmId, firedAt);
    completed.add(alarmId);
    final session = _sessions[alarmId];
    if (session != null) {
      _sessions[alarmId] = session.copyWith(
        completedAt: DateTime.now(),
        clearDeadline: true,
        clearSnoozedUntil: true,
      );
    }
  }

  @override
  Future<void> abortMission(String alarmId, {DateTime? firedAt}) async {
    await _syncEvents();
    _matching(alarmId, firedAt);
    aborted.add(alarmId);
    final session = _sessions[alarmId];
    if (session != null) {
      _sessions[alarmId] = session.copyWith(
        completedAt: DateTime.now(),
        clearDeadline: true,
        clearSnoozedUntil: true,
      );
    }
  }

  @override
  Future<List<MissionStopEvent>> consumeMissionEvents({String? alarmId}) async {
    final selected = alarmId ?? pendingEvents.firstOrNull?.alarmId;
    final events = pendingEvents.where((e) => e.alarmId == selected).toList();
    pendingEvents = pendingEvents.where((e) => e.alarmId != selected).toList();
    return events;
  }

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
  Future<void> cancelAlarm(String id) async {
    cancelled.add(id);
    _accepted.removeWhere((_, entry) => entry.alarm.id == id);
    _sessions.remove(id);
    _enabledRoots?.remove(id);
  }

  @override
  Future<void> cancelAllAlarms() async => cancelAllCount++;
  @override
  Future<String?> importCustomSound(String sourcePath) async => null;
}
