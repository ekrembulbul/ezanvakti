/// `stopIntent` tarafından kuyruğa yazılan "alarm durduruldu" olayı.
///
/// Intent, Flutter engine ayakta olmadan da çalışabildiği için olay native
/// tarafta biriktirilir; uygulama öne gelince tüketilir.
class MissionStopEvent {
  final String alarmId;
  final DateTime stoppedAt;

  /// Kaynak çalışın zamanı; erteleme veya geç durdurma bunu değiştirmez.
  final DateTime? firedAt;
  final int? snoozeUsed;
  final int? rearmCount;

  /// Native zincir sert tavana (süre/tekrar) çarptı: bu bir durdurma değil,
  /// "zincir bitti" bildirimi. Görev ekranı açılmaz; oturum kapatılır.
  final bool chainStopped;

  const MissionStopEvent({
    required this.alarmId,
    required this.stoppedAt,
    this.firedAt,
    this.snoozeUsed,
    this.rearmCount,
    this.chainStopped = false,
  });

  factory MissionStopEvent.fromMap(Map<Object?, Object?> map) =>
      MissionStopEvent(
        alarmId: map['alarmId'] as String,
        stoppedAt: DateTime.fromMillisecondsSinceEpoch(
          (map['stoppedAt'] as num).toInt(),
        ),
        firedAt: map['firedAt'] is num
            ? DateTime.fromMillisecondsSinceEpoch(
                (map['firedAt'] as num).toInt(),
              )
            : null,
        snoozeUsed: (map['snoozeUsed'] as num?)?.toInt(),
        rearmCount: (map['rearmCount'] as num?)?.toInt(),
        chainStopped: map['chainStopped'] == true,
      );
}
