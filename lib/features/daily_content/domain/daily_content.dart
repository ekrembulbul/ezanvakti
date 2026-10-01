import '../../../core/exceptions/parse_exception.dart';

/// Diyanet'in günlük ayet, hadis ve duası. Metinler Diyanet'ten geldiği gibi
/// (tırnaklarıyla) tutulur; uygulama değiştirmez.
class DailyContent {
  /// Türkiye günü, `YYYY-MM-DD`.
  final String date;
  final String verse;
  final String verseSource;
  final String hadith;
  final String hadithSource;
  final String prayer;
  final String? prayerSource;

  const DailyContent({
    required this.date,
    required this.verse,
    required this.verseSource,
    required this.hadith,
    required this.hadithSource,
    required this.prayer,
    this.prayerSource,
  });

  /// [date]'in takvim günü (yerel, saat 00:00).
  DateTime get day {
    final parsed = DateTime.parse(date);
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// Zorunlu alan eksik ya da tarih biçimsizse [ParseException].
  factory DailyContent.fromJson(Map<String, dynamic> json) {
    String required(String key) {
      final value = json[key];
      if (value is String && value.isNotEmpty) return value;
      throw ParseException(
        message: 'daily content field "$key" missing',
        context: 'DailyContent.fromJson',
      );
    }

    final date = required('date');
    if (DateTime.tryParse(date) == null) {
      throw ParseException(
        message: 'daily content date "$date" invalid',
        context: 'DailyContent.fromJson',
      );
    }
    final prayerSource = json['prayerSource'];
    return DailyContent(
      date: date,
      verse: required('verse'),
      verseSource: required('verseSource'),
      hadith: required('hadith'),
      hadithSource: required('hadithSource'),
      prayer: required('prayer'),
      prayerSource: prayerSource is String && prayerSource.isNotEmpty
          ? prayerSource
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'verse': verse,
    'verseSource': verseSource,
    'hadith': hadith,
    'hadithSource': hadithSource,
    'prayer': prayer,
    'prayerSource': prayerSource,
  };
}
