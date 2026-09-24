import '../../../core/models/hijri_date.dart';

/// Ramazan ayının tespiti — günün Diyanet Hicri tarihinden.
///
/// Veri yoksa (eski önbellek, henüz çekilmemiş gün) Ramazan **kabul edilmez**;
/// tahmin yapılmaz.
class RamadanMode {
  const RamadanMode._();

  static const int ramadanMonth = 9;

  static bool isActiveFor(HijriDate? hijri) => hijri?.month == ramadanMonth;

  /// Ramazan'ın kaçıncı günü (1–30); Ramazan dışında ya da veri yoksa `null`.
  static int? dayOfRamadanFor(HijriDate? hijri) =>
      hijri != null && hijri.month == ramadanMonth ? hijri.day : null;
}
