/// Kütüphaneye kayıtlı bir QR kodu: alarm kurarken yeniden seçilebilsin diye
/// etiketiyle saklanır. `Alarm.qrPayload` bu kayıttan bağımsız bir kopyadır —
/// kütüphaneden silmek mevcut alarmı bozmaz.
class QrCodeEntry {
  final String id;
  final String label;
  final String payload;
  final DateTime createdAt;

  const QrCodeEntry({
    required this.id,
    required this.label,
    required this.payload,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'label': label,
    'payload': payload,
    'created_at': createdAt.toIso8601String(),
  };

  factory QrCodeEntry.fromMap(Map<String, Object?> map) => QrCodeEntry(
    id: map['id'] as String,
    label: map['label'] as String,
    payload: map['payload'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}
