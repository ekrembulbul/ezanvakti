import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/config/mission_tuning.dart';
import '../../core/di/service_locator.dart';
import '../../core/models/alarm.dart';
import '../../core/models/alarm_mission.dart';
import '../../features/alarms/domain/abort_gate.dart';
import '../../features/alarms/domain/alarms_manager.dart';
import '../../features/alarms/domain/mission_coordinator.dart';
import '../widgets/missions/abort_dialog.dart';
import '../widgets/missions/math_mission.dart';
import 'mission_screen.dart';

/// Bekleyen bir görev oturumu varsa görev ekranını açar.
///
/// Uygulama, alarm durdurulunca `stopIntent` tarafından öne getiriliyor;
/// buraya hem soğuk açılışta hem de ön plana dönüşte uğranır.
Future<void> openMissionIfPending(BuildContext context) async {
  final coordinator = ServiceLocator().get<MissionCoordinator>();
  final session = await coordinator.resume();
  if (session == null || !session.isPending) return;

  final alarms = await ServiceLocator().get<AlarmsManager>().getAlarms();
  final alarm = alarms.where((a) => a.id == session.alarmId).firstOrNull;
  // Alarm silinmisse ortada gorev yok; zinciri de kapat ki telefon susmasin
  // diye bir sey beklemesin.
  if (alarm == null || !alarm.mission.requiresGate) {
    await coordinator.complete(session.alarmId);
    return;
  }

  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _MissionHost(alarm: alarm, snoozeUsed: session.snoozeUsed),
    ),
  );
}

/// Görev ekranını sayaçla birlikte çalıştıran kabuk.
class _MissionHost extends StatefulWidget {
  final Alarm alarm;
  final int snoozeUsed;

  const _MissionHost({required this.alarm, required this.snoozeUsed});

  @override
  State<_MissionHost> createState() => _MissionHostState();
}

class _MissionHostState extends State<_MissionHost> {
  late int _remaining;
  Timer? _ticker;

  MissionCoordinator get _coordinator =>
      ServiceLocator().get<MissionCoordinator>();

  @override
  void initState() {
    super.initState();
    _remaining = MissionTuning.timeoutSecondsFor(widget.alarm.mission);
    // Native tarafa haber ver: nobetci `grace`ten gorev suresine tasinsin.
    _coordinator.begin(widget.alarm.id);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int get _snoozeRemaining {
    final limit = widget.alarm.maxSnoozes;
    if (!widget.alarm.snoozeEnabled || limit == null) return 0;
    final left = limit - widget.snoozeUsed;
    return left < 0 ? 0 : left;
  }

  Future<void> _complete() async {
    await _coordinator.complete(widget.alarm.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _snooze() async {
    final ok = await _coordinator.snooze(widget.alarm);
    if (ok && mounted) Navigator.of(context).pop();
  }

  Future<void> _abort() async {
    final state = await ServiceLocator()
        .get<MissionCoordinator>()
        .storage
        .getAbortState();
    final now = DateTime.now();
    final level = AbortGate.effectiveLevel(state: state, now: now);
    if (!mounted) return;
    final confirmed = await showAbortDialog(context: context, level: level);
    if (!confirmed) return;
    await _coordinator.abort(widget.alarm.id, DateTime.now());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Gorev ekrani geri tusuyla kapatilamaz; kapi burada.
      canPop: false,
      child: MissionScreen(
        alarm: widget.alarm,
        remainingSeconds: _remaining,
        snoozeRemaining: _snoozeRemaining,
        onCompleted: _complete,
        onAbortRequested: _abort,
        onSnooze: _snoozeRemaining > 0 ? _snooze : null,
        child: switch (widget.alarm.mission) {
          AlarmMission.math => MathMission(
            level: widget.alarm.missionLevel,
            random: Random(),
            onCompleted: _complete,
          ),
          // Sallama ve QR kendi turlarinda eklenecek; o zamana kadar bu
          // alarmlar gorev ekranina hic dusmez (arayuzde secilemiyorlar).
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}
