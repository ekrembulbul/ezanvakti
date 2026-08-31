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
import '../../core/models/mission_session.dart';
import '../../core/utils/app_logger.dart';
import '../../features/alarms/domain/abort_gate.dart';
import '../../features/alarms/domain/alarm_scheduler.dart';
import '../../features/alarms/domain/alarms_manager.dart';
import '../../features/alarms/domain/mission_coordinator.dart';
import '../../features/alarms/domain/stop_gate.dart';
import '../widgets/missions/abort_dialog.dart';
import '../widgets/missions/math_mission.dart';
import '../widgets/missions/qr_mission.dart';
import '../widgets/missions/shake_mission.dart';
import 'alarm_stop_screen.dart';
import 'mission_screen.dart';

/// Ekranı tutan Navigator. Aynı anda birden fazla ekran açılırsa her biri
/// kendi geri sayımını başlatıyor ve "Ertele" alttaki eski ekranı ortaya
/// çıkarıyordu.
///
/// Düz bir bool yerine Navigator tutuluyor: rota pop edilmeden ağaç ölürse
/// (testte yeni ağaç, üretimde kök değişimi) bayrak takılı kalmasın.
NavigatorState? _openScreenNavigator;

bool get _missionScreenOpen => _openScreenNavigator?.mounted ?? false;

/// Ara ekranın nasıl kapandığı.
enum StopScreenResult { done, mission }

/// Bekleyen bir oturum varsa uygun ekranı açar.
///
/// Uygulama, alarm durdurulunca `stopIntent` tarafından öne getiriliyor;
/// buraya hem soğuk açılışta hem de ön plana dönüşte uğranır. Karar
/// [StopGate]'te; burada yalnızca sonuç uygulanır.
Future<void> openMissionIfPending(BuildContext context) async {
  if (_missionScreenOpen) return;
  final coordinator = ServiceLocator().get<MissionCoordinator>();
  final result = await coordinator.resume();
  if (result.chainStoppedAlarmId != null) {
    // Zincir tavana carpti (K3): gorev borcu dustu, ekran acilmaz;
    // native zincir temizlenir ve yarinki calislar kurulur.
    await coordinator.complete(result.chainStoppedAlarmId!);
    if (context.mounted) {
      context.read<AppState>().setMissionSession(null);
      await rearmAlarms(context);
    }
    return;
  }
  final session = result.session;
  if (context.mounted) context.read<AppState>().setMissionSession(session);
  if (session == null || !session.isPending) return;

  final alarms = await ServiceLocator().get<AlarmsManager>().getAlarms();
  final alarm = alarms.where((a) => a.id == session.alarmId).firstOrNull;
  final decision = StopGate.decide(
    alarm: alarm,
    session: session,
    now: DateTime.now(),
  );

  switch (decision) {
    case StopDecision.none:
      return;
    case StopDecision.closeAndRearm:
      // Alarm silinmis, secim yok ya da bayat: zinciri kapat ki telefon
      // olmayan bir gorevi beklemesin; ertesi gunu kur.
      await coordinator.complete(session.alarmId);
      if (context.mounted) await rearmAlarms(context);
      return;
    case StopDecision.openMission:
    case StopDecision.showStopScreen:
      break;
  }

  if (!context.mounted) return;
  _openScreenNavigator = Navigator.of(context);
  try {
    // Bayrak ara ekran ve gorev ekrani boyunca true kalir: pushReplacement
    // yerine sirali iki push, cunku pushReplacement ilk rotanin Future'ini
    // erken tamamlayip bayragi dusururdu.
    var openMission = decision == StopDecision.openMission;
    if (!openMission) {
      final result = await Navigator.of(context).push<StopScreenResult>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _StopHost(alarm: alarm!, session: session),
        ),
      );
      openMission = result == StopScreenResult.mission;
    }
    if (openMission && context.mounted) {
      final current = await coordinator.currentSession();
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _MissionHost(
            alarm: alarm!,
            snoozeUsed: current?.snoozeUsed ?? session.snoozeUsed,
          ),
        ),
      );
    }
  } finally {
    _openScreenNavigator = null;
    if (context.mounted) {
      context.read<AppState>().setMissionSession(
        await coordinator.currentSession(),
      );
    }
  }
}

/// Ara ekranı sayaçla çalıştıran kabuk.
///
/// Görevlide sayaç `graceSeconds`: dolunca native nöbetçi alarmı döndürür,
/// burada yalnızca gösterilir. Görevsizde `stopScreenSeconds`: dolunca
/// "Tamam" sayılır ve ekran kendini kapatır (spec D3/D8).
class _StopHost extends StatefulWidget {
  final Alarm alarm;
  final MissionSession session;

  const _StopHost({required this.alarm, required this.session});

  @override
  State<_StopHost> createState() => _StopHostState();
}

class _StopHostState extends State<_StopHost> {
  late MissionSession _session = widget.session;
  Timer? _ticker;
  StreamSubscription<dynamic>? _stops;
  bool _closing = false;

  MissionCoordinator get _coordinator =>
      ServiceLocator().get<MissionCoordinator>();

  bool get _gated => widget.alarm.mission.requiresGate;

  int get _windowSeconds =>
      _gated ? MissionTuning.graceSeconds : MissionTuning.stopScreenSeconds;

  int get _remaining {
    final end = _session.stoppedAt.add(Duration(seconds: _windowSeconds));
    final left = end.difference(DateTime.now()).inSeconds;
    return left < 0 ? 0 : left;
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    // Gorevlide sure dolup alarm donerse ve yine durdurulursa geri sayim
    // yeni stoppedAt ile tazelenir; ikinci ekran acilmaz.
    _stops = ServiceLocator().get<AlarmService>().missionStops.listen((_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    final session = (await _coordinator.resume()).session;
    if (!mounted || session == null) return;
    setState(() => _session = session);
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (!_gated && _remaining <= 0) _primary();
  }

  Future<void> _primary() async {
    if (_closing) return;
    _closing = true;
    if (_gated) {
      Navigator.of(context).pop(StopScreenResult.mission);
      return;
    }
    await _coordinator.complete(widget.alarm.id);
    if (!mounted) return;
    await rearmAlarms(context);
    if (mounted) Navigator.of(context).pop(StopScreenResult.done);
  }

  Future<void> _snooze() async {
    if (_closing) return;
    final ok = await _coordinator.snooze(widget.alarm);
    if (!ok || !mounted) return;
    _closing = true;
    Navigator.of(context).pop(StopScreenResult.done);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stops?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = StopGate.snoozeRemaining(widget.alarm, _session);
    final canSnooze = remaining == null || remaining > 0;
    return PopScope(
      canPop: false,
      child: AlarmStopScreen(
        alarm: widget.alarm,
        gated: _gated,
        remainingSeconds: _remaining,
        snoozeRemaining: remaining,
        firedAt: _session.firedAt,
        stoppedAt: _session.stoppedAt,
        now: DateTime.now(),
        onPrimary: _primary,
        onSnooze: canSnooze ? _snooze : null,
      ),
    );
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
    if (!mounted) return;
    await rearmAlarms(context);
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
    if (!mounted) return;
    await rearmAlarms(context);
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

/// Zincir kapandıktan sonra alarmları yeniden kurar.
///
/// Native taraf görev bitince zinciri temizliyor; alarmlar AlarmKit'e tek
/// seferlik kurulduğu için bir sonraki çalışı yeniden kurmak Dart'ın işi.
/// Bu olmayınca cihazda görülen şey: Güneş alarmının QR görevi tamamlandı,
/// aynı güne kurulu 08:45 hiç çalmadı.
///
/// **Ertelemede çağrılmaz**: `scheduleAlarms` önce her şeyi iptal ediyor,
/// ertelemenin kurduğu nöbetçiyi de silerdi. Hata yukarı sızmaz — görev
/// ekranı kapanmalı; yeniden kurma bir sonraki öne gelişte tekrar denenir.
Future<void> rearmAlarms(BuildContext context) async {
  final appState = context.read<AppState>();
  try {
    await ServiceLocator().get<AlarmScheduler>().scheduleAlarms(
      prayerTimes: appState.prayerTimes,
      skips: appState.skips,
    );
  } catch (e, stackTrace) {
    AppLogger().warning('Gorev sonrasi alarm yeniden kurulamadi', e, stackTrace);
  }
}
