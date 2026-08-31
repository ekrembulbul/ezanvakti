import '../../../core/models/prayer_time.dart';

/// Ramazan sayacının neyi hedeflediği.
enum RamadanCountdownKind {
  /// İmsaka kalan süre — sahur biterken.
  suhoor,

  /// Akşama kalan süre — iftar.
  iftar,
}

/// Sayacın hedefi: hangi an ve neyi temsil ettiği.
class RamadanCountdownTarget {
  final RamadanCountdownKind kind;
  final DateTime time;

  const RamadanCountdownTarget({required this.kind, required this.time});
}

/// Ramazan'da ana ekrandaki sayacın hedefini seçer.
///
/// Gün üç parçaya bölünür: imsaktan önce sahur, imsak–akşam arası oruç
/// (iftara sayılır), akşamdan sonra ertesi günün sahuru. Saf: zamanı ve gün
/// verisini dışarıdan alır.
class RamadanCountdown {
  const RamadanCountdown._();

  static RamadanCountdownTarget? resolve({
    required DateTime now,
    required PrayerTime today,
    required PrayerTime? tomorrow,
  }) {
    if (now.isBefore(today.fajr)) {
      return RamadanCountdownTarget(
        kind: RamadanCountdownKind.suhoor,
        time: today.fajr,
      );
    }
    if (now.isBefore(today.maghrib)) {
      return RamadanCountdownTarget(
        kind: RamadanCountdownKind.iftar,
        time: today.maghrib,
      );
    }
    // Akşam geçti: sıradaki hedef ertesi günün imsakı. Veri yoksa sayaç
    // gösterilmez — yanlış bir hedefe saymaktansa hiç saymamak doğru.
    if (tomorrow == null) return null;
    return RamadanCountdownTarget(
      kind: RamadanCountdownKind.suhoor,
      time: tomorrow.fajr,
    );
  }
}
