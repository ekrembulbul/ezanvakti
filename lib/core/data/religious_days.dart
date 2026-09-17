import '../models/prayer_time.dart';
import '../models/religious_day.dart';

/// Günlerin Diyanet Hicri tarihinden dini günleri üretir.
///
/// Hicri hesaplanmaz; her gün sunucudan gelen Hicri'yi taşır. Kandil/bayram
/// günleri Hicri ay-gün sabitlerinden, Regaib Recep'in ilk Perşembesinden
/// türetilir. Hicri'si olmayan günler yok sayılır. Kayıtlar `isEstimated`
/// bayrağını korur: resmi liste (`/v1/religious-days`) gelince kaynak değişir.
class ReligiousDays {
  const ReligiousDays._();

  /// Hicri ay-gün sabitleri.
  static const List<
    ({int month, int day, ReligiousDayId id, ReligiousDayKind kind})
  >
  _fixed = [
    (
      month: 1,
      day: 1,
      id: ReligiousDayId.newYear,
      kind: ReligiousDayKind.other,
    ),
    (
      month: 1,
      day: 10,
      id: ReligiousDayId.ashura,
      kind: ReligiousDayKind.other,
    ),
    (
      month: 3,
      day: 12,
      id: ReligiousDayId.mawlid,
      kind: ReligiousDayKind.kandil,
    ),
    (
      month: 7,
      day: 27,
      id: ReligiousDayId.miraj,
      kind: ReligiousDayKind.kandil,
    ),
    (
      month: 8,
      day: 15,
      id: ReligiousDayId.baraat,
      kind: ReligiousDayKind.kandil,
    ),
    (
      month: 9,
      day: 1,
      id: ReligiousDayId.ramadanStart,
      kind: ReligiousDayKind.ramadanStart,
    ),
    (month: 9, day: 27, id: ReligiousDayId.qadr, kind: ReligiousDayKind.kandil),
    (
      month: 10,
      day: 1,
      id: ReligiousDayId.eidFitr,
      kind: ReligiousDayKind.bayram,
    ),
    (
      month: 12,
      day: 9,
      id: ReligiousDayId.arafah,
      kind: ReligiousDayKind.other,
    ),
    (
      month: 12,
      day: 10,
      id: ReligiousDayId.eidAdha,
      kind: ReligiousDayKind.bayram,
    ),
  ];

  /// [days] içindeki dini günler, tarihe göre sıralı, tekrarsız.
  static List<ReligiousDay> fromDays(Iterable<PrayerTime> days) {
    final result = <ReligiousDay>[];
    final seen = <String>{};

    for (final time in days) {
      final hijri = time.hijri;
      if (hijri == null) continue;
      final day = _dayStart(time.date);

      for (final entry in _fixed) {
        if (hijri.month != entry.month || hijri.day != entry.day) continue;
        _add(result, seen, day, entry.id, entry.kind);
      }

      // Regaib: Recep ayının ilk Perşembesi (Perşembeyi Cumaya bağlayan gece).
      if (hijri.month == 7 &&
          day.weekday == DateTime.thursday &&
          hijri.day <= 7) {
        _add(result, seen, day, ReligiousDayId.regaib, ReligiousDayKind.kandil);
      }
    }

    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  static void _add(
    List<ReligiousDay> result,
    Set<String> seen,
    DateTime date,
    ReligiousDayId id,
    ReligiousDayKind kind,
  ) {
    if (!seen.add('$date-${id.name}')) return;
    result.add(ReligiousDay(date: date, id: id, kind: kind));
  }

  static DateTime _dayStart(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
