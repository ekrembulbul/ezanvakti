import '../../../core/interfaces/alarm_service.dart';
import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/alarm.dart';
import '../../../core/config/mission_tuning.dart';
import '../../../core/models/alarm_mission.dart';
import '../../../core/models/mission_session.dart';
import 'abort_gate.dart';
import '../../../core/models/mission_stop_event.dart';

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

  MissionCoordinator({required this.alarmService, required this.storage});

  /// Uygulama öne geldiğinde çağrılır. Native kuyruğunda durdurma olayı varsa
  /// oturumu açar/yeniler, yoksa kayıtlı oturumu döner. Kuyrukta "zincir
  /// tavana çarptı" olayı varsa oturum kapatılır ve olay sonuçta işaretlenir;
  /// çağıran ekran açmaz, alarmları yeniden kurar.
  Future<ResumeResult> resume() async {
    final events = await alarmService.consumeMissionEvents();

    MissionStopEvent? chainStopped;
    for (final event in events) {
      if (event.chainStopped) chainStopped = event;
    }
    if (chainStopped != null) {
      await storage.saveMissionSession(null);
      return ResumeResult(
        session: null,
        chainStoppedAlarmId: chainStopped.alarmId,
      );
    }

    if (events.isEmpty) {
      return ResumeResult(session: await storage.getMissionSession());
    }

    final latest = events.last;
    final existing = await storage.getMissionSession();
    // Yeni durdurma olayi = alarm tekrar caldi ve kapatildi. Gorev penceresi
    // bastan baslamali, yoksa ekranda dolmus sayac 0'da cakili kalir.
    final session = existing != null && existing.alarmId == latest.alarmId
        ? existing.copyWith(
            rearmCount: existing.rearmCount + 1,
            stoppedAt: latest.stoppedAt,
            clearDeadline: true,
            // Alarm calip kapatildi: erteleme penceresi bitti.
            clearSnoozedUntil: true,
          )
        : MissionSession(alarmId: latest.alarmId, firedAt: latest.stoppedAt);
    await storage.saveMissionSession(session);
    return ResumeResult(session: session);
  }

  /// Görev ekranı açıldı. Son tarih **yalnızca ilk açılışta** konur; ekran
  /// yeniden açılsa da geri sayım baştan başlamaz.
  Future<DateTime?> begin(String alarmId, AlarmMission mission) async {
    await alarmService.beginMission(alarmId);
    final session = await storage.getMissionSession();
    if (session == null) return null;
    if (session.deadlineAt != null) return session.deadlineAt;
    final deadline = DateTime.now().add(
      Duration(seconds: MissionTuning.timeoutSecondsFor(mission)),
    );
    await storage.saveMissionSession(session.copyWith(deadlineAt: deadline));
    return deadline;
  }

  /// Erteleme denemesi. Hak kalmadıysa `false` döner ve hiçbir şey değişmez.
  ///
  /// Başarılıysa alarm gerçekten ertelenir: aktif nöbetçi iptal edilip alarm
  /// [Alarm.snoozeMinutes] sonrasına kurulur ve son tarih silinir — görev
  /// ekranı bir sonraki çalışta yeni süreyle açılır.
  Future<bool> snooze(Alarm alarm) async {
    final session = await storage.getMissionSession();
    if (session == null) return false;
    final limit = alarm.maxSnoozes;
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
  }

  /// Arayüzün göstereceği güncel oturum. Kuyruğu tüketmez.
  Future<MissionSession?> currentSession() => storage.getMissionSession();

  /// Görev tamamlandı: zincir tamamen susar.
  Future<void> complete(String alarmId) async {
    await alarmService.completeMission(alarmId);
    await storage.saveMissionSession(null);
  }

  /// Acil çıkış kullanıldı: zincir susar ve kademe bir yükselir.
  Future<void> abort(String alarmId, DateTime now) async {
    await alarmService.abortMission(alarmId);
    await storage.saveMissionSession(null);
    final current = await storage.getAbortState();
    await storage.saveAbortState(AbortGate.escalate(state: current, now: now));
  }
}
