/// Atlanan örneğin türü.
enum SkipKind { notification, alarm }

/// Tek bir bildirim/alarm örneğinin "yalnızca bu sefer" atlanması.
///
/// [reference] bildirim için `NotificationScheduler`'ın ürettiği kimlik
/// (gün · vakit · offset), alarm için alarmın kendi id'si. [fireAt] ile
/// birlikte tek bir örneği işaret eder: aynı alarmın farklı günleri ayrı
/// kayıtlardır.
class SkippedOccurrence {
  final SkipKind kind;
  final String reference;
  final DateTime fireAt;

  const SkippedOccurrence({
    required this.kind,
    required this.reference,
    required this.fireAt,
  });

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'reference': reference,
    'fireAt': fireAt.toIso8601String(),
  };

  /// Bozuk kayıt burada değil çağıran tarafta ele alınır; [SqliteStorage]
  /// çözümleme hatasında listeyi boş kabul eder.
  factory SkippedOccurrence.fromJson(Map<String, dynamic> json) {
    return SkippedOccurrence(
      kind: SkipKind.values.byName(json['kind'] as String),
      reference: json['reference'] as String,
      fireAt: DateTime.parse(json['fireAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SkippedOccurrence &&
      other.kind == kind &&
      other.reference == reference &&
      other.fireAt == fireAt;

  @override
  int get hashCode => Object.hash(kind, reference, fireAt);

  @override
  String toString() => 'SkippedOccurrence(${kind.name}, $reference, $fireAt)';
}
