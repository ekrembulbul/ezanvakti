import 'hijri_date.dart';

class PrayerTime {
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final DateTime date;

  /// Günün Diyanet Hicri tarihi; eski önbellek satırlarında ve Hicri
  /// vermeyen kaynaklarda `null` (arayüz Hicri satırını gizler).
  final HijriDate? hijri;

  const PrayerTime({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.date,
    this.hijri,
  });

  Map<String, dynamic> toJson() {
    return {
      'fajr': fajr.toIso8601String(),
      'sunrise': sunrise.toIso8601String(),
      'dhuhr': dhuhr.toIso8601String(),
      'asr': asr.toIso8601String(),
      'maghrib': maghrib.toIso8601String(),
      'isha': isha.toIso8601String(),
      'date': date.toIso8601String(),
      'hijri': hijri?.toJson(),
    };
  }

  factory PrayerTime.fromJson(Map<String, dynamic> json) {
    return PrayerTime(
      fajr: DateTime.parse(json['fajr'] as String),
      sunrise: DateTime.parse(json['sunrise'] as String),
      dhuhr: DateTime.parse(json['dhuhr'] as String),
      asr: DateTime.parse(json['asr'] as String),
      maghrib: DateTime.parse(json['maghrib'] as String),
      isha: DateTime.parse(json['isha'] as String),
      date: DateTime.parse(json['date'] as String),
      hijri: _hijriFrom(json),
    );
  }

  /// Hem JSON'daki iç içe `hijri` nesnesini hem SQLite satırındaki düz
  /// `hijri_day/hijri_month/hijri_year` sütunlarını kabul eder.
  static HijriDate? _hijriFrom(Map<String, dynamic> json) {
    final nested = json['hijri'];
    if (nested is Map<String, dynamic>) return HijriDate.fromJson(nested);
    final day = json['hijri_day'];
    final month = json['hijri_month'];
    final year = json['hijri_year'];
    if (day is int && month is int && year is int) {
      return HijriDate(day: day, month: month, year: year);
    }
    return null;
  }

  PrayerTime copyWith({
    DateTime? fajr,
    DateTime? sunrise,
    DateTime? dhuhr,
    DateTime? asr,
    DateTime? maghrib,
    DateTime? isha,
    DateTime? date,
    HijriDate? hijri,
  }) {
    return PrayerTime(
      fajr: fajr ?? this.fajr,
      sunrise: sunrise ?? this.sunrise,
      dhuhr: dhuhr ?? this.dhuhr,
      asr: asr ?? this.asr,
      maghrib: maghrib ?? this.maghrib,
      isha: isha ?? this.isha,
      date: date ?? this.date,
      hijri: hijri ?? this.hijri,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerTime &&
          runtimeType == other.runtimeType &&
          fajr == other.fajr &&
          sunrise == other.sunrise &&
          dhuhr == other.dhuhr &&
          asr == other.asr &&
          maghrib == other.maghrib &&
          isha == other.isha &&
          date == other.date &&
          hijri == other.hijri;

  @override
  int get hashCode =>
      Object.hash(fajr, sunrise, dhuhr, asr, maghrib, isha, date, hijri);
}
