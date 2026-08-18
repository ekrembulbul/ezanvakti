/// Çalan bir alarmın görev oturumu. `Alarm` kullanıcı tercihidir, bu geçici
/// durumdur — bu yüzden ayrı saklanır.
///
/// Aynı anda en fazla bir aktif oturum olur.
class MissionSession {
  final String alarmId;
  final DateTime firedAt;
  final int snoozeUsed;
  final int rearmCount;

  /// Görev süresinin **mutlak** bitişi. Görev ekranı ilk açıldığında konur ve
  /// bir daha değişmez: ekran yeniden açılsa da geri sayım baştan başlamaz,
  /// uygulama arka plana düşse de sayaç durmaz.
  final DateTime? deadlineAt;

  /// Erteleme yapıldıysa alarmın tekrar çalacağı an. Arayüz bunu alarm
  /// satırında ve ana ekranda gösterir.
  final DateTime? snoozedUntil;

  final DateTime? completedAt;

  const MissionSession({
    required this.alarmId,
    required this.firedAt,
    this.snoozeUsed = 0,
    this.rearmCount = 0,
    this.deadlineAt,
    this.snoozedUntil,
    this.completedAt,
  });

  bool get isPending => completedAt == null;

  Map<String, dynamic> toJson() => {
    'alarm_id': alarmId,
    'fired_at': firedAt.toIso8601String(),
    'snooze_used': snoozeUsed,
    'rearm_count': rearmCount,
    'deadline_at': deadlineAt?.toIso8601String(),
    'snoozed_until': snoozedUntil?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
  };

  factory MissionSession.fromJson(Map<String, dynamic> json) => MissionSession(
    alarmId: json['alarm_id'] as String,
    firedAt: DateTime.parse(json['fired_at'] as String),
    snoozeUsed: json['snooze_used'] as int? ?? 0,
    rearmCount: json['rearm_count'] as int? ?? 0,
    deadlineAt: switch (json['deadline_at']) {
      final String s => DateTime.tryParse(s),
      _ => null,
    },
    snoozedUntil: switch (json['snoozed_until']) {
      final String s => DateTime.tryParse(s),
      _ => null,
    },
    completedAt: switch (json['completed_at']) {
      final String s => DateTime.tryParse(s),
      _ => null,
    },
  );

  MissionSession copyWith({
    int? snoozeUsed,
    int? rearmCount,
    DateTime? deadlineAt,
    DateTime? snoozedUntil,
    DateTime? completedAt,
    bool clearDeadline = false,
    bool clearSnoozedUntil = false,
  }) => MissionSession(
    alarmId: alarmId,
    firedAt: firedAt,
    snoozeUsed: snoozeUsed ?? this.snoozeUsed,
    rearmCount: rearmCount ?? this.rearmCount,
    deadlineAt: clearDeadline ? null : (deadlineAt ?? this.deadlineAt),
    snoozedUntil: clearSnoozedUntil
        ? null
        : (snoozedUntil ?? this.snoozedUntil),
    completedAt: completedAt ?? this.completedAt,
  );
}
