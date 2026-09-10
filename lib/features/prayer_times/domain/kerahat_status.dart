import 'kerahat_times.dart';

/// Şu anın kerahat aralıklarına göre durumu.
sealed class KerahatStatus {
  final KerahatInterval interval;
  const KerahatStatus(this.interval);
}

/// Kerahat henüz başlamadı; başlangıca [KerahatWarning.lead] ya da daha az
/// kaldı.
class KerahatApproaching extends KerahatStatus {
  const KerahatApproaching(super.interval);
}

/// Şu an kerahat aralığının içinde.
class KerahatActive extends KerahatStatus {
  const KerahatActive(super.interval);
}

/// Kerahat uyarısının kuralı; saf, zamanı dışarıdan alır.
///
/// Akşam öncesi kerahat ikindinin gerçek son sınırıdır: sayaç akşamı
/// gösterirken namaz için kalan süre aslında daha kısadır. Yarım saat, namazı
/// kılmaya yetecek ama gün boyu uyarı basmayacak kadar dar bir pencere.
abstract final class KerahatWarning {
  static const Duration lead = Duration(minutes: 30);

  /// Aralıklar çakışmadığı için ilk eşleşen döner. İçindeyse aktif; başlangıca
  /// [lead] ya da daha az kaldıysa yaklaşıyor; aksi hâlde `null`.
  static KerahatStatus? resolve(List<KerahatInterval> intervals, DateTime now) {
    for (final interval in intervals) {
      if (interval.contains(now)) return KerahatActive(interval);
    }
    for (final interval in intervals) {
      if (now.isBefore(interval.start) &&
          !interval.start.difference(now).isNegative &&
          interval.start.difference(now) <= lead) {
        return KerahatApproaching(interval);
      }
    }
    return null;
  }
}
