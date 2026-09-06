import '../../../core/models/derived_time.dart';
import '../../../core/models/prayer_time.dart';
import 'derived_times.dart';

/// Gün içindeki yaklaşık kerahat aralığının türü.
enum KerahatKind { afterSunrise, beforeDhuhr, beforeMaghrib }

/// Başlangıcı dahil, bitişi hariç yaklaşık kerahat aralığı.
class KerahatInterval {
  final KerahatKind kind;
  final DateTime start;
  final DateTime end;

  const KerahatInterval({
    required this.kind,
    required this.start,
    required this.end,
  });

  bool contains(DateTime instant) =>
      !instant.isBefore(start) && instant.isBefore(end);
}

/// Bir günlük yaklaşık kerahat aralıklarını mevcut türetilmiş vakitlerle
/// aynı sınırlardan hesaplar.
class KerahatTimes {
  const KerahatTimes._();

  static List<KerahatInterval> forDay(
    PrayerTime day, {
    DerivedTimeSettings settings = DerivedTimeSettings.defaults,
  }) {
    if (!_hasValidPrayerOrder(day)) return const [];

    final ishraq = DerivedTimes.resolve(
      kind: DerivedTimeKind.ishraq,
      day: day,
      settings: settings,
    );
    final istiwa = DerivedTimes.resolve(
      kind: DerivedTimeKind.istiwa,
      day: day,
      settings: settings,
    );
    final preMaghrib = DerivedTimes.resolve(
      kind: DerivedTimeKind.preMaghrib,
      day: day,
      settings: settings,
    );

    final candidates = <KerahatInterval>[
      if (ishraq != null)
        KerahatInterval(
          kind: KerahatKind.afterSunrise,
          start: day.sunrise,
          end: ishraq,
        ),
      if (istiwa != null)
        KerahatInterval(
          kind: KerahatKind.beforeDhuhr,
          start: istiwa,
          end: day.dhuhr,
        ),
      if (preMaghrib != null)
        KerahatInterval(
          kind: KerahatKind.beforeMaghrib,
          start: preMaghrib,
          end: day.maghrib,
        ),
    ];

    final startOfDay = DateTime(day.date.year, day.date.month, day.date.day);
    final startOfNextDay = DateTime(
      day.date.year,
      day.date.month,
      day.date.day + 1,
    );

    return [
      for (final interval in candidates)
        if (!interval.end.isAfter(startOfNextDay) &&
            !interval.start.isBefore(startOfDay) &&
            interval.end.isAfter(interval.start))
          interval,
    ];
  }

  static bool _hasValidPrayerOrder(PrayerTime day) {
    final startOfDay = DateTime(day.date.year, day.date.month, day.date.day);
    final startOfNextDay = DateTime(
      day.date.year,
      day.date.month,
      day.date.day + 1,
    );
    final prayers = [
      day.fajr,
      day.sunrise,
      day.dhuhr,
      day.asr,
      day.maghrib,
      day.isha,
    ];

    if (prayers.any(
      (prayer) =>
          prayer.isBefore(startOfDay) || !prayer.isBefore(startOfNextDay),
    )) {
      return false;
    }

    for (var index = 1; index < prayers.length; index++) {
      if (!prayers[index].isAfter(prayers[index - 1])) return false;
    }
    return true;
  }
}
