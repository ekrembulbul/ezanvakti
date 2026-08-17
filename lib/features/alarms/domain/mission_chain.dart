import '../../../core/config/mission_tuning.dart';
import '../../../core/models/alarm_mission.dart';

/// Zincirin o anki durumu. Native taraf bu değerleri UserDefaults'tan okur;
/// hesapları burada, tek yerde yapılır — Swift yalnızca iki karşılaştırma
/// yapar, mantığı taşımaz.
class ChainState {
  final int rearmCount;

  /// Zincirin sert süre tavanı. Alarmın çaldığı andan itibaren işler.
  final DateTime chainDeadline;

  /// Yürürlükteki sayacın bitişi: `grace` ya da görev süresi.
  final DateTime deadline;

  const ChainState({
    required this.rearmCount,
    required this.chainDeadline,
    required this.deadline,
  });
}

enum ChainDecision { rearm, stop }

/// Nöbetçi zincirinin kararlarını ve tarihlerini hesaplar. Saf fonksiyonlar;
/// zamanı dışarıdan alır, `DateTime.now()` çağırmaz.
class MissionChain {
  const MissionChain._();

  /// Zincir devam etmeli mi? Tavanlardan biri dolduysa durur.
  static ChainDecision decide({
    required ChainState state,
    required DateTime now,
  }) {
    if (state.rearmCount >= MissionTuning.maxRearms) return ChainDecision.stop;
    if (!now.isBefore(state.chainDeadline)) return ChainDecision.stop;
    return ChainDecision.rearm;
  }

  /// Alarm durduruldu, görev ekranı henüz açılmadı.
  static DateTime deadlineAfterStop(DateTime now) =>
      now.add(const Duration(seconds: MissionTuning.graceSeconds));

  /// Görev ekranı açıldı; sayaç görev süresine geçer.
  static DateTime deadlineAfterBegin({
    required DateTime now,
    required AlarmMission mission,
  }) => now.add(Duration(seconds: MissionTuning.timeoutSecondsFor(mission)));

  static DateTime chainDeadline(DateTime firedAt) =>
      firedAt.add(const Duration(minutes: MissionTuning.chainDeadlineMinutes));

  /// `stopIntent` hiç çalışmazsa devreye giren, önden kurulan yedekler.
  static List<DateTime> ladder(DateTime firedAt) => [
    for (var i = 1; i <= MissionTuning.ladderCount; i++)
      firedAt.add(Duration(minutes: MissionTuning.ladderStepMinutes * i)),
  ];

  /// Nöbetçi alarmın id'si. Ana alarmla çakışmaması şart: defter iptali bu id
  /// üzerinden yapıyor.
  static String watchdogId(String alarmId, int index) => '$alarmId#w$index';
}
