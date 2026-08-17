/// Çalan bir alarmın görev oturumu. `Alarm` kullanıcı tercihidir, bu geçici
/// durumdur — bu yüzden ayrı saklanır.
///
/// Aynı anda en fazla bir aktif oturum olur.
class MissionSession {
  final String alarmId;
  final DateTime firedAt;
  final int snoozeUsed;
  final int rearmCount;
  final DateTime? completedAt;

  const MissionSession({
    required this.alarmId,
    required this.firedAt,
    this.snoozeUsed = 0,
    this.rearmCount = 0,
    this.completedAt,
  });

  bool get isPending => completedAt == null;

  Map<String, dynamic> toJson() => {
    'alarm_id': alarmId,
    'fired_at': firedAt.toIso8601String(),
    'snooze_used': snoozeUsed,
    'rearm_count': rearmCount,
    'completed_at': completedAt?.toIso8601String(),
  };

  factory MissionSession.fromJson(Map<String, dynamic> json) => MissionSession(
    alarmId: json['alarm_id'] as String,
    firedAt: DateTime.parse(json['fired_at'] as String),
    snoozeUsed: json['snooze_used'] as int? ?? 0,
    rearmCount: json['rearm_count'] as int? ?? 0,
    completedAt: switch (json['completed_at']) {
      final String s => DateTime.tryParse(s),
      _ => null,
    },
  );

  MissionSession copyWith({
    int? snoozeUsed,
    int? rearmCount,
    DateTime? completedAt,
  }) => MissionSession(
    alarmId: alarmId,
    firedAt: firedAt,
    snoozeUsed: snoozeUsed ?? this.snoozeUsed,
    rearmCount: rearmCount ?? this.rearmCount,
    completedAt: completedAt ?? this.completedAt,
  );
}
