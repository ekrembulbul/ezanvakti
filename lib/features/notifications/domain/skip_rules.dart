import '../../../core/models/skipped_occurrence.dart';

/// Verilen örnek atlanmış mı?
///
/// **Kart ve planlayıcı bu tek sorgu üzerinden ilerler.** Aynı kimliği aynı
/// vakit verisinden türettikleri için ikisi ayrışamaz: kayıt eşleşiyorsa alarm
/// çalmaz ve anahtar kapalı görünür, eşleşmiyorsa alarm çalar ve anahtar açık
/// görünür.
bool isSkipped(
  Set<SkippedOccurrence> skips, {
  required SkipKind kind,
  required String reference,
  required DateTime fireAt,
}) {
  return skips.contains(
    SkippedOccurrence(kind: kind, reference: reference, fireAt: fireAt),
  );
}

/// Tetiklenme anı geçmiş kayıtları eler.
///
/// Kullanıcının ayrıca "geri aç" demesi gerekmez; örnek geçince atlama
/// kendiliğinden ölür ve ertesi gün normal çalar.
Set<SkippedOccurrence> withoutExpired(
  Iterable<SkippedOccurrence> skips,
  DateTime now,
) {
  return skips.where((skip) => !skip.fireAt.isBefore(now)).toSet();
}
