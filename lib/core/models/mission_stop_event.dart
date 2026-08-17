/// `stopIntent` tarafından kuyruğa yazılan "alarm durduruldu" olayı.
///
/// Intent, Flutter engine ayakta olmadan da çalışabildiği için olay native
/// tarafta biriktirilir; uygulama öne gelince tüketilir.
class MissionStopEvent {
  final String alarmId;
  final DateTime stoppedAt;

  const MissionStopEvent({required this.alarmId, required this.stoppedAt});

  factory MissionStopEvent.fromMap(Map<Object?, Object?> map) =>
      MissionStopEvent(
        alarmId: map['alarmId'] as String,
        stoppedAt: DateTime.fromMillisecondsSinceEpoch(
          (map['stoppedAt'] as num).toInt(),
        ),
      );
}
