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
import '../../features/alarms/domain/snooze_options.dart';
import '../../l10n/l10n_extensions.dart';
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
bool _needsMissionCheck = false;

bool get _missionScreenOpen => _openScreenNavigator?.mounted ?? false;

bool get _canPresentMission {
  final state = WidgetsBinding.instance.lifecycleState;
  return state == null || state == AppLifecycleState.resumed;
}

/// Ara ekranın nasıl kapandığı.
enum StopScreenResult { done, mission }

void _showMissionFailure(
  BuildContext context,
  Object error,
  StackTrace stack,
  Future<void> Function() retry,
) {
  AppLogger().warning('Mission action failed', error, stack);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(context.l10n.errorGeneric),
        action: SnackBarAction(
          label: context.l10n.actionRetry,
          onPressed: () => unawaited(retry()),
        ),
      ),
    );
}

/// Bekleyen bir oturum varsa uygun ekranı açar.
///
/// Native stop yalnız durumu kaydeder. Buraya kullanıcı uygulamayı açınca veya
/// uygulama zaten ön plandayken bir durdurma olayı geldiğinde uğranır. Karar
/// [StopGate]'te; burada yalnızca sonuç uygulanır.
Future<void> openMissionIfPending(BuildContext context) async {
  if (!context.mounted || !_canPresentMission) return;
  if (_missionScreenOpen) {
    _needsMissionCheck = true;
    return;
  }
  final navigator = Navigator.of(context);
  _openScreenNavigator = navigator;
  final coordinator = ServiceLocator().get<MissionCoordinator>();
  try {
    bool checkNext;
    do {
      _needsMissionCheck = false;
      checkNext = await _openNextMission(context);
    } while (context.mounted && (checkNext || _needsMissionCheck));
  } catch (error, stack) {
    if (context.mounted) {
      _showMissionFailure(
        context,
        error,
        stack,
        () => openMissionIfPending(context),
      );
    }
  } finally {
    if (identical(_openScreenNavigator, navigator)) _openScreenNavigator = null;
    if (context.mounted) {
      try {
        final sessions = await coordinator.currentSessions();
        if (context.mounted) {
          context.read<AppState>().setMissionSessions(sessions);
        }
      } catch (error, stack) {
        if (context.mounted) {
          _showMissionFailure(
            context,
            error,
            stack,
            () => openMissionIfPending(context),
          );
        }
      }
    }
  }
}

Future<bool> _openNextMission(BuildContext context) async {
  if (!_canPresentMission) return false;
  final coordinator = ServiceLocator().get<MissionCoordinator>();
  final result = await coordinator.resume();
  if (result.chainStoppedAlarmId != null) {
    // Zincir tavana carpti (K3): gorev borcu dustu, ekran acilmaz;
    // native zincir temizlenir ve yarinki calislar kurulur.
    await coordinator.complete(
      result.chainStoppedAlarmId!,
      firedAt: result.session?.firedAt,
    );
    final sessions = await coordinator.currentSessions();
    if (context.mounted) {
      context.read<AppState>().setMissionSessions(sessions);
      await rearmAlarms(context);
    }
    return true;
  }
  final session = result.session;
  if (context.mounted) {
    context.read<AppState>().setMissionSessions(result.sessions);
  }
  if (session == null || !session.isPending) return false;

  final alarms = await ServiceLocator().get<AlarmsManager>().getAlarms();
  final alarm = alarms.where((a) => a.id == session.alarmId).firstOrNull;
  final decision = StopGate.decide(
    alarm: alarm,
    session: session,
    now: DateTime.now(),
  );

  switch (decision) {
    case StopDecision.none:
      return false;
    case StopDecision.closeAndRearm:
      // Alarm silinmis, secim yok ya da bayat: zinciri kapat ki telefon
      // olmayan bir gorevi beklemesin; ertesi gunu kur.
      await coordinator.complete(session.alarmId, firedAt: session.firedAt);
      if (context.mounted) await rearmAlarms(context);
      return true;
    case StopDecision.openMission:
    case StopDecision.showStopScreen:
      break;
  }

  if (!context.mounted || !_canPresentMission) return false;
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
  if (openMission && context.mounted && _canPresentMission) {
    final current = await coordinator.currentSession();
    if (!context.mounted || !_canPresentMission) return false;
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _MissionHost(
          alarm: alarm!,
          session:
              current?.alarmId == session.alarmId &&
                  current!.firedAt.isAtSameMomentAs(session.firedAt)
              ? current
              : session,
        ),
      ),
    );
  }
  return true;
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

class _StopHostState extends State<_StopHost> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    // Gorevlide sure dolup alarm donerse ve yine durdurulursa geri sayim
    // yeni stoppedAt ile tazelenir; ikinci ekran acilmaz.
    _stops = ServiceLocator()
        .get<AlarmService>()
        .missionStops
        .where((event) => event.alarmId == widget.alarm.id)
        .listen((_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final result = await _coordinator.resume(alarmId: widget.alarm.id);
      if (result.chainStoppedAlarmId != null) {
        await _coordinator.complete(
          widget.alarm.id,
          firedAt: widget.session.firedAt,
        );
        if (mounted) {
          await rearmAlarms(context);
          if (mounted) Navigator.of(context).pop(StopScreenResult.done);
        }
        return;
      }
      final session = result.session;
      if (!mounted) return;
      if (session == null ||
          !session.firedAt.isAtSameMomentAs(widget.session.firedAt)) {
        if (!_closing) {
          _closing = true;
          Navigator.of(context).pop(StopScreenResult.done);
        }
        return;
      }
      context.read<AppState>().setMissionSessions(result.sessions);
      setState(() => _session = session);
    } catch (error, stack) {
      if (mounted) _showMissionFailure(context, error, stack, _refresh);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
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
    try {
      await _coordinator.complete(
        widget.alarm.id,
        firedAt: widget.session.firedAt,
      );
      if (!mounted) return;
      await rearmAlarms(context);
      if (mounted) Navigator.of(context).pop(StopScreenResult.done);
    } catch (error, stack) {
      _closing = false;
      _ticker?.cancel();
      if (mounted) _showMissionFailure(context, error, stack, _primary);
    }
  }

  Future<void> _snooze() async {
    if (_closing) return;
    _closing = true;
    try {
      final ok = await _coordinator.snooze(
        widget.alarm,
        firedAt: widget.session.firedAt,
      );
      if (!ok || !mounted) {
        _closing = false;
        return;
      }
      Navigator.of(context).pop(StopScreenResult.done);
    } catch (error, stack) {
      _closing = false;
      if (mounted) _showMissionFailure(context, error, stack, _snooze);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
  final MissionSession session;

  const _MissionHost({required this.alarm, required this.session});

  @override
  State<_MissionHost> createState() => _MissionHostState();
}

class _MissionHostState extends State<_MissionHost>
    with WidgetsBindingObserver {
  bool _closing = false;
  late MissionSession _session = widget.session;

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
    WidgetsBinding.instance.addObserver(this);
    // Native tarafa haber ver: nobetci `grace`ten gorev suresine tasinsin.
    unawaited(_begin());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // Sure dolup alarm tekrar caldiginda ekran zaten acik oluyor; yeni turun
    // suresini almazsak sayac 0'da cakili kalir.
    _stops = ServiceLocator()
        .get<AlarmService>()
        .missionStops
        .where((event) => event.alarmId == widget.alarm.id)
        .listen((_) => _refreshDeadline());
  }

  Future<void> _begin() async {
    if (!_canPresentMission) return;
    try {
      final deadline = await _coordinator.begin(
        widget.alarm.id,
        widget.alarm.mission,
        firedAt: widget.session.firedAt,
      );
      if (!mounted) return;
      if (deadline == null) {
        if (!_closing) {
          _closing = true;
          Navigator.of(context).pop();
        }
        return;
      }
      final sessions = await _coordinator.currentSessions();
      if (!mounted) return;
      context.read<AppState>().setMissionSessions(sessions);
      setState(() {
        _deadline = deadline;
        _session =
            MissionSession.pendingForAlarm(sessions, widget.alarm.id) ??
            _session;
      });
    } catch (error, stack) {
      if (mounted) _showMissionFailure(context, error, stack, _begin);
    }
  }

  Future<void> _refreshDeadline() async {
    if (!_canPresentMission) return;
    try {
      final result = await _coordinator.resume(alarmId: widget.alarm.id);
      if (result.chainStoppedAlarmId != null) {
        await _complete();
        return;
      }
      await _begin();
    } catch (error, stack) {
      if (mounted) _showMissionFailure(context, error, stack, _refreshDeadline);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshDeadline());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _stops?.cancel();
    super.dispose();
  }

  int get _snoozeRemaining {
    final limit = effectiveSnoozeLimit(widget.alarm);
    if (!widget.alarm.snoozeEnabled || limit == null) return 0;
    final left = limit - _session.snoozeUsed;
    return left < 0 ? 0 : left;
  }

  Future<void> _complete() async {
    if (_closing) return;
    _closing = true;
    try {
      await _coordinator.complete(
        widget.alarm.id,
        firedAt: widget.session.firedAt,
      );
      if (!mounted) return;
      await rearmAlarms(context);
      if (mounted) Navigator.of(context).pop();
    } catch (error, stack) {
      _closing = false;
      if (mounted) _showMissionFailure(context, error, stack, _complete);
    }
  }

  Future<void> _snooze() async {
    if (_closing) return;
    _closing = true;
    try {
      final ok = await _coordinator.snooze(
        widget.alarm,
        firedAt: widget.session.firedAt,
      );
      if (!ok || !mounted) {
        _closing = false;
        return;
      }
      // Erteleme bilgisi alarm satirinda ve ana ekranda gosteriliyor; burada
      // ayrica bir onay ekrani tutmuyoruz.
      Navigator.of(context).pop();
    } catch (error, stack) {
      _closing = false;
      if (mounted) _showMissionFailure(context, error, stack, _snooze);
    }
  }

  Future<void> _abort() async {
    if (_closing) return;
    _closing = true;
    try {
      final state = await _coordinator.storage.getAbortState();
      if (!mounted) return;
      final confirmed = await showAbortDialog(
        context: context,
        level: AbortGate.effectiveLevel(state: state, now: DateTime.now()),
      );
      if (!confirmed) {
        _closing = false;
        return;
      }
      await _finishAbort(DateTime.now());
    } catch (error, stack) {
      _closing = false;
      if (mounted) _showMissionFailure(context, error, stack, _abort);
    }
  }

  Future<void> _finishAbort(DateTime requestedAt) async {
    _closing = true;
    try {
      await _coordinator.abort(
        widget.alarm.id,
        requestedAt,
        firedAt: widget.session.firedAt,
      );
      if (!mounted) return;
      await rearmAlarms(context);
      if (mounted) Navigator.of(context).pop();
    } catch (error, stack) {
      _closing = false;
      if (mounted) {
        _showMissionFailure(
          context,
          error,
          stack,
          () => _finishAbort(requestedAt),
        );
      }
    }
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

/// Görev tamamlanınca tarihli planın ufkunu yeniler. Native uzlaştırma diğer
/// alarmları ve ertelemeleri korur. Yenileme hatası tamamlanan görevi açmaz;
/// hata kaydedilir ve sonraki öne gelişte plan tekrar uzlaştırılır.
Future<void> rearmAlarms(BuildContext context) async {
  final appState = context.read<AppState>();
  try {
    await ServiceLocator().get<AlarmScheduler>().scheduleAlarms(
      prayerTimes: appState.prayerTimes,
      skips: appState.skips,
    );
  } catch (e, stackTrace) {
    AppLogger().warning(
      'Gorev sonrasi alarm yeniden kurulamadi',
      e,
      stackTrace,
    );
  }
}
