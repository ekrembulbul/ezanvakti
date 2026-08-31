import 'package:hijri/hijri_calendar.dart';

/// Ramazan ayının tespiti.
///
/// Kaynak `ReligiousDays` ile aynı: tabular hicri takvim. Bu yüzden başlangıç
/// günü Diyanet ilanından bir gün sapabilir; mod bir gün erken/geç açılabilir
/// ama içerik doğru kalır (sayaç zaten o günün vakitlerinden hesaplanıyor).
class RamadanMode {
  const RamadanMode._();

  /// Hicri takvimde Ramazan'ın ay numarası.
  static const int _ramadanMonth = 9;

  static bool isActive(DateTime date) =>
      HijriCalendar.fromDate(_dayStart(date)).hMonth == _ramadanMonth;

  /// Ramazan'ın kaçıncı günü (1–30); Ramazan dışında `null`.
  static int? dayOfRamadan(DateTime date) {
    final hijri = HijriCalendar.fromDate(_dayStart(date));
    return hijri.hMonth == _ramadanMonth ? hijri.hDay : null;
  }

  static DateTime _dayStart(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
