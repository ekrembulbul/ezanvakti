import '../../../core/interfaces/alarm_service.dart';
import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/alarm.dart';
import '../../../core/config/mission_tuning.dart';
import '../../../core/models/alarm_mission.dart';
import '../../../core/models/mission_session.dart';
import 'abort_gate.dart';
import '../../../core/utils/app_logger.dart';
import 'snooze_options.dart';

/// [MissionCoordinator.resume] sonucu: güncel oturum ve varsa "zincir tavana
/// çarptı" bilgisi.
class ResumeResult {
  final MissionSession? session;

  /// Dolu ise: native zincir sert tavana çarptı. Görev ekranı açılmamalı;
  /// çağıran `complete` ile zinciri temizleyip alarmları yeniden kurmalı.
  final String? chainStoppedAlarmId;

  const ResumeResult({required this.session, this.chainStoppedAlarmId});
}

/// Görev oturumunun yaşam döngüsünü yürütür: native olayları tüketir,
/// oturumu saklar, erteleme sayacını tutar, tamamlama ve acil çıkışta
/// zincirin temizlenmesini tetikler.
class MissionCoordinator {
  final AlarmService alarmService;
  final LocalStorage storage;
  Future<void>? _operations;

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

  /// Uygulama öne geldiğinde çağrılır. Native kuyruğunda durdurma olayı varsa
  /// oturumu açar/yeniler, yoksa kayıtlı oturumu döner. Kuyrukta "zincir
  /// tavana çarptı" olayı varsa oturum kapatılır ve olay sonuçta işaretlenir;
  /// çağıran ekran açmaz, alarmları yeniden kurar.
  Future<ResumeResult> resume({String? alarmId}) => _serial(() async {
    final events = await alarmService.consumeMissionEvents(alarmId: alarmId);
    final existing = await storage.getMissionSession();
    if (events.isEmpty) {
      return ResumeResult(session: existing);
    }

    final latest = events.last;
    if (latest.chainStopped) {
      if (existing?.alarmId == latest.alarmId) {
        await storage.saveMissionSession(null);
      }
      return ResumeResult(session: null, chainStoppedAlarmId: latest.alarmId);
    }
    final sameOccurrence =
        existing != null &&
        existing.alarmId == latest.alarmId &&
        (latest.firedAt == null || latest.firedAt == existing.firedAt);
    // Yeni durdurma olayi = alarm tekrar caldi ve kapatildi. Gorev penceresi
    // bastan baslamali, yoksa ekranda dolmus sayac 0'da cakili kalir.
    final session = MissionSession(
      alarmId: latest.alarmId,
      firedAt:
          latest.firedAt ??
          (sameOccurrence ? existing.firedAt : latest.stoppedAt),
      stoppedAt: latest.stoppedAt,
      snoozeUsed:
          latest.snoozeUsed ?? (sameOccurrence ? existing.snoozeUsed : 0),
      rearmCount:
          latest.rearmCount ?? (sameOccurrence ? existing.rearmCount + 1 : 0),
    );
    await storage.saveMissionSession(session);
    return ResumeResult(session: session);
  });

  /// Görev ekranı açıldı. Son tarih **yalnızca ilk açılışta** konur; ekran
  /// yeniden açılsa da geri sayım baştan başlamaz.
  Future<DateTime?> begin(String alarmId, AlarmMission mission) => _serial(
    () async {
      final session = await storage.getMissionSession();
      if (session == null || !session.isPending || session.alarmId != alarmId) {
        return null;
      }
      if (session.deadlineAt != null) return session.deadlineAt;
      await alarmService.beginMission(alarmId);
      final deadline = DateTime.now().add(
        Duration(seconds: MissionTuning.timeoutSecondsFor(mission)),
      );
      await storage.saveMissionSession(session.copyWith(deadlineAt: deadline));
      return deadline;
    },
  );

  /// Erteleme denemesi. Hak kalmadıysa `false` döner ve hiçbir şey değişmez.
  ///
  /// Başarılıysa alarm gerçekten ertelenir: aktif nöbetçi iptal edilip alarm
  /// [Alarm.snoozeMinutes] sonrasına kurulur ve son tarih silinir — görev
  /// ekranı bir sonraki çalışta yeni süreyle açılır.
  Future<bool> snooze(Alarm alarm) => _serial(() async {
    final session = await storage.getMissionSession();
    if (!alarm.snoozeEnabled ||
        session == null ||
        !session.isPending ||
        session.alarmId != alarm.id) {
      return false;
    }
    final limit = effectiveSnoozeLimit(alarm);
    if (limit != null && session.snoozeUsed >= limit) return false;
    await alarmService.snoozeMission(alarm.id, alarm.snoozeMinutes);
    await storage.saveMissionSession(
      session.copyWith(
        snoozeUsed: session.snoozeUsed + 1,
        clearDeadline: true,
        snoozedUntil: DateTime.now().add(
          Duration(minutes: alarm.snoozeMinutes),
        ),
      ),
    );
    return true;
  });

  /// Arayüzün göstereceği güncel oturum. Kuyruğu tüketmez.
  Future<MissionSession?> currentSession() =>
      _serial(storage.getMissionSession);

  /// Görev tamamlandı: zincir tamamen susar.
  Future<void> complete(String alarmId) => _serial(() async {
    final session = await storage.getMissionSession();
    await alarmService.completeMission(alarmId);
    if (session?.alarmId == alarmId) await storage.saveMissionSession(null);
  });

  /// Acil çıkış kullanıldı: zincir susar ve kademe bir yükselir.
  Future<void> abort(String alarmId, DateTime now) => _serial(() async {
    final session = await storage.getMissionSession();
    if (session?.alarmId != alarmId) return;
    await alarmService.abortMission(alarmId);
    await storage.saveMissionSession(null);
    final current = await storage.getAbortState();
    await storage.saveAbortState(AbortGate.escalate(state: current, now: now));
  });
}
