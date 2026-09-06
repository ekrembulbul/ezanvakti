/// Diyanet's published month boundaries; Eid is excluded.
class RamadanPeriod {
  final int hijriYear;
  final DateTime start;
  final DateTime eid;
  final List<String> sourceUrls;

  RamadanPeriod({
    required this.hijriYear,
    required this.start,
    required this.eid,
    required List<String> sourceUrls,
  }) : sourceUrls = List.unmodifiable(sourceUrls) {
    if (dayCount != 29 && dayCount != 30) {
      throw ArgumentError('Ramadan must contain 29 or 30 calendar days');
    }
  }

  int get dayCount => DateTime.utc(
    eid.year,
    eid.month,
    eid.day,
  ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
  DateTime get lastDay => DateTime(eid.year, eid.month, eid.day - 1);
  List<DateTime> get days => List.generate(
    dayCount,
    (i) => DateTime(start.year, start.month, start.day + i),
  );
}
