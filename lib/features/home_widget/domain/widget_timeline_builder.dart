import '../../../core/models/prayer_time.dart';
import '../../../core/theme/day_phase.dart';
import '../../prayer_times/domain/kerahat_status.dart';
import '../../prayer_times/domain/kerahat_times.dart';
import 'widget_snapshot.dart';

/// Widget'ın görünümünün değiştiği bütün anları önceden hesaplar.
///
/// Saf: vakitler ve "şimdi" dışarıdan gelir. Android widget'ı ve sabit satır
/// hesap yapmaz, yalnız o anki girişi seçer (ADR 0004); kural burada,
/// uygulamanın kendi fonksiyonlarıyla tek yerde kalır:
/// - sıradaki vakit: zamanı andan büyük ilk vakit,
/// - kerahat: [KerahatWarning.resolve] (30 dk önce yaklaşma, aralıkta aktif),
/// - gün dilimi: [resolveDayPhase].
///
/// Anlar: şimdi, her vakit, her kerahat aralığının yaklaşma/başlangıç/bitişi
/// ve gün başları. Son vakitten sonrası üretilmez: sıradaki vakit kalmaz,
/// widget o noktada "güncel değil"e düşer.
class WidgetTimelineBuilder {
  const WidgetTimelineBuilder._();

  static List<WidgetTimelineEntry> build({
    required List<PrayerTime> days,
    required DateTime now,
  }) {
    if (days.isEmpty) return const [];
    final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));

    final slots = <({int day, int slot, DateTime time})>[
      for (var day = 0; day < sorted.length; day++)
        for (final (slot, time) in _ordered(sorted[day]).indexed)
          (day: day, slot: slot, time: time),
    ]..sort((a, b) => a.time.compareTo(b.time));
    if (slots.isEmpty) return const [];

    final intervals = [for (final day in sorted) ...KerahatTimes.forDay(day)];
    final lastSlot = slots.last.time;

    final moments =
        <DateTime>{
              now,
              for (final slot in slots) slot.time,
              for (final interval in intervals) ...[
                interval.start.subtract(KerahatWarning.lead),
                interval.start,
                interval.end,
              ],
              for (final day in sorted.skip(1)) _dayStart(day.date),
            }
            .where(
              (moment) => !moment.isBefore(now) && moment.isBefore(lastSlot),
            )
            .toList()
          ..sort();

    final entries = <WidgetTimelineEntry>[];
    for (final moment in moments) {
      final next = slots.firstWhere(
        (slot) => slot.time.isAfter(moment),
        orElse: () => slots.last,
      );
      if (!next.time.isAfter(moment)) continue;
      final status = KerahatWarning.resolve(intervals, moment);
      entries.add(
        WidgetTimelineEntry(
          at: moment,
          day: next.day,
          slot: next.slot,
          tomorrow: !_sameDay(sorted[next.day].date, moment),
          phase: _phase(sorted, moment),
          kerahat: switch (status) {
            KerahatActive(:final interval) => WidgetTimelineKerahat(
              state: WidgetKerahatState.active,
              start: interval.start,
              end: interval.end,
            ),
            KerahatApproaching(:final interval) => WidgetTimelineKerahat(
              state: WidgetKerahatState.approaching,
              start: interval.start,
              end: interval.end,
            ),
            null => null,
          },
        ),
      );
    }
    return entries;
  }

  static List<DateTime> _ordered(PrayerTime day) => [
    day.fajr,
    day.sunrise,
    day.dhuhr,
    day.asr,
    day.maghrib,
    day.isha,
  ];

  static DateTime _dayStart(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Anın takvim gününün dilimi; o günün verisi yoksa yedek dilim.
  static DayPhase _phase(List<PrayerTime> days, DateTime moment) {
    final index = days.indexWhere((day) => _sameDay(day.date, moment));
    return resolveDayPhase(
      today: index < 0 ? null : days[index],
      tomorrow: index < 0 || index + 1 >= days.length ? null : days[index + 1],
      now: moment,
    );
  }
}
