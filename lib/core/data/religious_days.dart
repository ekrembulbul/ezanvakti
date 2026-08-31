import 'package:hijri/hijri_calendar.dart';

import '../models/religious_day.dart';

/// Hicri takvimden dini günleri üretir.
///
/// **Tarihler hesaplanmıştır, ilan edilmiş değildir.** Diyanet takvimi
/// astronomik gözleme dayanır; buradaki tabular hicri hesap bir gün
/// sapabilir. Bu yüzden her kayıt `isEstimated: true` gelir ve arayüz bunu
/// kullanıcıya bildirir. İleride doğrulanmış bir tablo eklenirse bu sınıfın
/// sözleşmesi değişmeden yalnızca kaynağı değişir.
class ReligiousDays {
  const ReligiousDays._();

  /// Hicri ay-gün sabitleri.
  static const List<({int month, int day, String name, ReligiousDayKind kind})>
  _fixed = [
    (month: 1, day: 1, name: 'Hicri Yılbaşı', kind: ReligiousDayKind.other),
    (month: 1, day: 10, name: 'Aşure Günü', kind: ReligiousDayKind.other),
    (month: 3, day: 12, name: 'Mevlid Kandili', kind: ReligiousDayKind.kandil),
    (month: 7, day: 27, name: 'Miraç Kandili', kind: ReligiousDayKind.kandil),
    (month: 8, day: 15, name: 'Berat Kandili', kind: ReligiousDayKind.kandil),
    (
      month: 9,
      day: 1,
      name: 'Ramazan Başlangıcı',
      kind: ReligiousDayKind.ramadanStart,
    ),
    (month: 9, day: 27, name: 'Kadir Gecesi', kind: ReligiousDayKind.kandil),
    (month: 10, day: 1, name: 'Ramazan Bayramı', kind: ReligiousDayKind.bayram),
    (month: 12, day: 9, name: 'Arefe Günü', kind: ReligiousDayKind.other),
    (month: 12, day: 10, name: 'Kurban Bayramı', kind: ReligiousDayKind.bayram),
  ];

  /// [start] ile [end] arasındaki (dahil) dini günler, tarihe göre sıralı.
  static List<ReligiousDay> forRange(DateTime start, DateTime end) {
    final from = _dayStart(start);
    final to = _dayStart(end);
    if (to.isBefore(from)) return const [];

    final result = <ReligiousDay>[];
    final seen = <String>{};

    for (var day = from; !day.isAfter(to); day = _nextDay(day)) {
      final hijri = HijriCalendar.fromDate(day);

      for (final entry in _fixed) {
        if (hijri.hMonth != entry.month || hijri.hDay != entry.day) continue;
        _add(result, seen, day, entry.name, entry.kind);
      }

      // Regaib: Recep ayının ilk Perşembesi (Perşembeyi Cumaya bağlayan gece).
      if (hijri.hMonth == 7 &&
          day.weekday == DateTime.thursday &&
          hijri.hDay <= 7) {
        _add(result, seen, day, 'Regaib Kandili', ReligiousDayKind.kandil);
      }
    }

    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  static void _add(
    List<ReligiousDay> result,
    Set<String> seen,
    DateTime date,
    String name,
    ReligiousDayKind kind,
  ) {
    if (!seen.add('$date-$name')) return;
    result.add(ReligiousDay(date: date, name: name, kind: kind));
  }

  static DateTime _dayStart(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Takvim tabanlı ilerleme: yaz saati geçişlerindeki 23/25 saatlik günler
  /// gün atlamasına yol açmasın.
  static DateTime _nextDay(DateTime date) =>
      DateTime(date.year, date.month, date.day + 1);
}
