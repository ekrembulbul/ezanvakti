import '../../../core/models/notification_setting.dart' show PrayerType;
import '../../../core/models/prayer_time.dart';
import '../../../core/models/quiet_interval.dart';
import '../../../core/models/quiet_window.dart';

/// Sessiz pencerelerden telefonun Rahatsız Etme'de olacağı aralıkları çıkarır.
///
/// Saf: zaman ve veri dışarıdan gelir. Sonuç sıralı ve birleştirilmiştir —
/// çakışan ya da uç uca değen aralıklar tek aralık olur, böylece native taraf
/// arada modu kapatıp açmaz. Bitmiş aralıklar atılır, süren aralık kalır.
class QuietPhonePlanner {
  const QuietPhonePlanner._();

  static List<QuietInterval> plan({
    required List<QuietWindow> windows,
    required List<PrayerTime> prayerTimes,
    required DateTime now,
  }) {
    final raw = <QuietInterval>[];
    for (final window in windows) {
      if (!window.isActive || !window.silencePhone) continue;
      final type = window.trigger == QuietTrigger.fridayDhuhr
          ? PrayerType.dhuhr
          : window.prayerType;
      if (type == null) continue;
      for (final day in prayerTimes) {
        final prayerAt = _timeOf(day, type);
        if (!window.matchesPrayer(type, prayerAt)) continue;
        final start = prayerAt.subtract(
          Duration(minutes: window.minutesBefore),
        );
        final end = prayerAt.add(Duration(minutes: window.minutesAfter));
        if (!end.isAfter(start) || !end.isAfter(now)) continue;
        raw.add(QuietInterval(start, end));
      }
    }
    raw.sort((a, b) => a.start.compareTo(b.start));
    final merged = <QuietInterval>[];
    for (final interval in raw) {
      final last = merged.isEmpty ? null : merged.last;
      if (last != null && !interval.start.isAfter(last.end)) {
        merged[merged.length - 1] = QuietInterval(
          last.start,
          interval.end.isAfter(last.end) ? interval.end : last.end,
        );
      } else {
        merged.add(interval);
      }
    }
    return merged;
  }

  static DateTime _timeOf(PrayerTime day, PrayerType type) => switch (type) {
    PrayerType.fajr => day.fajr,
    PrayerType.sunrise => day.sunrise,
    PrayerType.dhuhr => day.dhuhr,
    PrayerType.asr => day.asr,
    PrayerType.maghrib => day.maghrib,
    PrayerType.isha => day.isha,
  };
}
