import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/config/mission_tuning.dart';
import 'package:provider/provider.dart';

import '../../core/di/service_locator.dart';
import '../../core/providers/app_state.dart';
import '../../core/interfaces/alarm_service.dart';
import '../../core/models/alarm.dart';
import '../../core/models/alarm_mission.dart';
import '../../features/alarms/domain/abort_gate.dart';
import '../../features/alarms/domain/alarms_manager.dart';
import '../../features/alarms/domain/mission_coordinator.dart';
import '../widgets/missions/abort_dialog.dart';
import '../widgets/missions/math_mission.dart';
import '../widgets/missions/qr_mission.dart';
import '../widgets/missions/shake_mission.dart';
import 'mission_screen.dart';

/// Görev ekranı açık mı? Aynı anda birden fazla açılırsa her biri kendi geri
/// sayımını başlatıyor ve "Ertele" alttaki eski ekranı ortaya çıkarıyordu.
bool _missionScreenOpen = false;

/// Bekleyen bir görev oturumu varsa görev ekranını açar.
///
/// Uygulama, alarm durdurulunca `stopIntent` tarafından öne getiriliyor;
/// buraya hem soğuk açılışta hem de ön plana dönüşte uğranır.
Future<void> openMissionIfPending(BuildContext context) async {
  if (_missionScreenOpen) return;
  final coordinator = ServiceLocator().get<MissionCoordinator>();
  final session = await coordinator.resume();
  if (context.mounted) context.read<AppState>().setMissionSession(session);
  if (session == null || !session.isPending) return;

  // Alarm ertelendiyse ortada calan bir alarm yok; gorev ekrani bir sonraki
  // calista acilir. Bilgi alarm satirinda ve ana ekranda duruyor.
  final snoozedUntil = session.snoozedUntil;
  if (snoozedUntil != null && snoozedUntil.isAfter(DateTime.now())) return;

  final alarms = await ServiceLocator().get<AlarmsManager>().getAlarms();
  final alarm = alarms.where((a) => a.id == session.alarmId).firstOrNull;
  // Alarm silinmisse ortada gorev yok; zinciri de kapat ki telefon susmasin
  // diye bir sey beklemesin.
  if (alarm == null || !alarm.mission.requiresGate) {
    await coordinator.complete(session.alarmId);
    return;
  }

  if (!context.mounted) return;
  _missionScreenOpen = true;
  try {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            _MissionHost(alarm: alarm, snoozeUsed: session.snoozeUsed),
      ),
    );
  } finally {
    _missionScreenOpen = false;
    if (context.mounted) {
      context.read<AppState>().setMissionSession(
        await coordinator.currentSession(),
      );
    }
  }
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

  /// Görev süresinin mutlak bitişi. Geri sayım bundan hesaplanır; ekran
  /// yeniden açılsa da baştan başlamaz, arka planda da işlemeye devam eder.
  DateTime? _deadline;

  Timer? _ticker;
  StreamSubscription<dynamic>? _stops;

  MissionCoordinator get _coordinator =>
      ServiceLocator().get<MissionCoordinator>();

  int get _remaining {
    final deadline = _deadline;
    if (deadline == null) {
      return MissionTuning.timeoutSecondsFor(widget.alarm.mission);
    }
    final left = deadline.difference(DateTime.now()).inSeconds;
    return left < 0 ? 0 : left;
  }

  @override
  void initState() {
    super.initState();
    // Native tarafa haber ver: nobetci `grace`ten gorev suresine tasinsin.
    _coordinator.begin(widget.alarm.id, widget.alarm.mission).then((deadline) {
      if (mounted) setState(() => _deadline = deadline);
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // Sure dolup alarm tekrar caldiginda ekran zaten acik oluyor; yeni turun
    // suresini almazsak sayac 0'da cakili kalir.
    _stops = ServiceLocator().get<AlarmService>().missionStops.listen((_) {
      _refreshDeadline();
    });
  }

  Future<void> _refreshDeadline() async {
    await _coordinator.resume();
    final deadline = await _coordinator.begin(
      widget.alarm.id,
      widget.alarm.mission,
    );
    if (!mounted) return;
    setState(() {
      _deadline = deadline;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stops?.cancel();
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
    if (!ok || !mounted) return;
    // Erteleme bilgisi alarm satirinda ve ana ekranda gosteriliyor; burada
    // ayrica bir onay ekrani tutmuyoruz.
    Navigator.of(context).pop();
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

  /// Görev gövdesi **bir kez** kuruluyor.
  ///
  /// Sayaç saniyede bir `setState` çağırıyor; gövde her karede yeniden
  /// yaratılırsa alt ağaç da yeniden kuruluyor ve QR görevinde kamera
  /// önizlemesi donuyordu. Aynı örnek geçildiğinde Flutter o alt ağacı hiç
  /// yeniden inşa etmiyor.
  late final Widget _body = switch (widget.alarm.mission) {
    AlarmMission.math => MathMission(
      level: widget.alarm.missionLevel,
      random: Random(),
      onCompleted: _complete,
    ),
    AlarmMission.shake => ShakeMission(
      level: widget.alarm.missionLevel,
      onCompleted: _complete,
    ),
    AlarmMission.qr => QrMission(
      expected: widget.alarm.qrPayload ?? '',
      onCompleted: _complete,
    ),
    AlarmMission.none => const SizedBox.shrink(),
  };

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
        child: _body,
      ),
    );
  }
}
