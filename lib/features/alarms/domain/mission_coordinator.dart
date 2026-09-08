import '../../../core/interfaces/alarm_service.dart';
import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/alarm.dart';
import '../../../core/models/alarm_mission.dart';
import '../../../core/models/mission_session.dart';
import '../../../core/utils/app_logger.dart';
import 'abort_gate.dart';
import 'snooze_options.dart';

class ResumeResult {
  final MissionSession? session;
  final List<MissionSession> sessions;
  final String? chainStoppedAlarmId;
  const ResumeResult({
    required this.session,
    this.sessions = const [],
    this.chainStoppedAlarmId,
  });
}

/// Native sessions are authoritative; Flutter only selects the presented one.
class MissionCoordinator {
  final AlarmService alarmService;
  final LocalStorage storage;
  Future<void>? _operations;
  List<MissionSession> _sessions = const [];
  ({String id, DateTime fire})? _selected;

  MissionCoordinator({required this.alarmService, required this.storage});

  Future<T> _serial<T>(Future<T> Function() operation) {
    final previous = _operations;
    final result = previous == null
        ? Future<T>.sync(operation)
        : previous.then((_) => operation());
    _operations = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        AppLogger().warning('Mission operation failed', error, stack);
      },
    );
    return result;
  }

  Future<void> _refresh() async {
    _sessions = List.unmodifiable(
      (await alarmService.getMissionSessions()).where(
        (session) => session.isPending,
      ),
    );
  }

  MissionSession? _find(String id, [DateTime? firedAt]) => _sessions
      .where(
        (session) =>
            session.alarmId == id &&
            (firedAt == null || session.firedAt.isAtSameMomentAs(firedAt)),
      )
      .firstOrNull;

  MissionSession? _actionable() {
    final now = DateTime.now();
    final ready =
        _sessions
            .where(
              (session) =>
                  session.snoozedUntil == null ||
                  !session.snoozedUntil!.isAfter(now),
            )
            .toList()
          ..sort((left, right) {
            final time = left.firedAt.compareTo(right.firedAt);
            return time != 0 ? time : left.alarmId.compareTo(right.alarmId);
          });
    return ready.firstOrNull;
  }

  Future<ResumeResult> resume({String? alarmId}) => _serial(() async {
    await _refresh();
    final session = alarmId == null ? _actionable() : _find(alarmId);
    _selected = session == null
        ? null
        : (id: session.alarmId, fire: session.firedAt);
    final expired =
        session?.chainDeadlineAt != null &&
        !session!.chainDeadlineAt!.isAfter(DateTime.now());
    return ResumeResult(
      session: session,
      sessions: _sessions,
      chainStoppedAlarmId: expired ? session.alarmId : null,
    );
  });

  Future<void> _apply(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error, stack) {
      // A new timer may be accepted before cleanup fails; show its actual state.
      try {
        await _refresh();
      } catch (snapshotError) {
        AppLogger().warning(
          'Mission snapshot recovery failed',
          snapshotError.runtimeType,
        );
      }
      Error.throwWithStackTrace(error, stack);
    }
    await _refresh();
  }

  Future<DateTime?> begin(
    String alarmId,
    AlarmMission mission, {
    DateTime? firedAt,
  }) => _serial(() async {
    await _refresh();
    final session = _find(alarmId, firedAt);
    if (session == null || !mission.requiresGate) return null;
    await _apply(
      () => alarmService.beginMission(alarmId, firedAt: session.firedAt),
    );
    return _find(alarmId, session.firedAt)?.deadlineAt;
  });

  Future<bool> snooze(Alarm alarm, {DateTime? firedAt}) => _serial(() async {
    await _refresh();
    final session = _find(alarm.id, firedAt);
    if (!alarm.snoozeEnabled || session == null) return false;
    final limit = effectiveSnoozeLimit(alarm);
    final alreadySnoozed =
        session.snoozedUntil?.isAfter(DateTime.now()) == true;
    if (!alreadySnoozed && limit != null && session.snoozeUsed >= limit) {
      return false;
    }
    await _apply(
      () => alarmService.snoozeMission(
        alarm.id,
        alarm.snoozeMinutes,
        firedAt: session.firedAt,
      ),
    );
    return true;
  });

  Future<List<MissionSession>> currentSessions() => _serial(() async {
    await _refresh();
    return _sessions;
  });

  Future<MissionSession?> currentSession() => _serial(() async {
    await _refresh();
    final selected = _selected;
    return (selected == null ? null : _find(selected.id, selected.fire)) ??
        _actionable() ??
        _sessions.firstOrNull;
  });

  Future<void> complete(
    String alarmId, {
    DateTime? firedAt,
  }) => _serial(() async {
    await _refresh();
    final session = _find(alarmId, firedAt);
    // A caller holding the occurrence can retry cleanup after native completion.
    if (session == null && _find(alarmId) != null) return;
    final fire = firedAt ?? session?.firedAt;
    if (fire == null) return;
    await _apply(() => alarmService.completeMission(alarmId, firedAt: fire));
  });

  Future<void> abort(String alarmId, DateTime now, {DateTime? firedAt}) =>
      _serial(() async {
        await _refresh();
        final session = _find(alarmId, firedAt);
        if (session == null && _find(alarmId) != null) return;
        final fire = firedAt ?? session?.firedAt;
        if (fire == null) return;
        await _apply(() => alarmService.abortMission(alarmId, firedAt: fire));
        final current = await storage.getAbortState();
        if (current.lastUsedAt?.isAtSameMomentAs(now) == true) return;
        await storage.saveAbortState(
          AbortGate.escalate(state: current, now: now),
        );
      });
}
