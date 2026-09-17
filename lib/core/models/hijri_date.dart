/// Diyanet takvimindeki Hicri tarih (gün 1–30, ay 1–12).
///
/// Hesaplanmaz; sunucudan gelen vakit satırıyla birlikte saklanır. Ay adı
/// çeviriden gelir (`HijriFormatter`), model ad taşımaz.
class HijriDate {
  final int day;
  final int month;
  final int year;

  const HijriDate({required this.day, required this.month, required this.year});

  Map<String, dynamic> toJson() => {'day': day, 'month': month, 'year': year};

  factory HijriDate.fromJson(Map<String, dynamic> json) {
    final day = json['day'];
    final month = json['month'];
    final year = json['year'];
    if (day is! int || month is! int || year is! int) {
      throw const FormatException('hijri date requires int day/month/year');
    }
    if (day < 1 || day > 30 || month < 1 || month > 12) {
      throw FormatException('hijri date out of range: $day/$month/$year');
    }
    return HijriDate(day: day, month: month, year: year);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HijriDate &&
          runtimeType == other.runtimeType &&
          day == other.day &&
          month == other.month &&
          year == other.year;

  @override
  int get hashCode => Object.hash(day, month, year);

  @override
  String toString() => '$day/$month/$year';
}
