import '../../../core/models/location.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/utils/hijri_formatter.dart';
import 'widget_snapshot.dart';

/// Vakit listesini widget penceresine çeviren saf dönüşüm.
///
/// Platform bağımlılığı yoktur; testin asıl hedefi burasıdır.
class WidgetSnapshotBuilder {
  const WidgetSnapshotBuilder._();

  /// Payload'a yazılan en fazla gün sayısı. Önbellek 30 gün ileriyi tuttuğu
  /// için (`prayer_times_repository.dart:11`) bu pencere bedavadır ve
  /// uygulama bir hafta açılmasa bile widget'ı doğru tutar.
  static const int maxDays = 7;

  static WidgetSnapshot build({
    required Location location,
    required List<PrayerTime> prayerTimes,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);

    final upcoming =
        prayerTimes.where((time) => !_dayOf(time.date).isBefore(today)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    return WidgetSnapshot(
      locationLabel: location.displayName,
      generatedAt: now,
      days: upcoming.take(maxDays).map(_toDay).toList(),
    );
  }

  static DateTime _dayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static WidgetSnapshotDay _toDay(PrayerTime time) {
    final day = _dayOf(time.date);
    return WidgetSnapshotDay(
      date: day,
      hijri: HijriFormatter.format(day),
      times: WidgetDayTimes(
        fajr: time.fajr,
        sunrise: time.sunrise,
        dhuhr: time.dhuhr,
        asr: time.asr,
        maghrib: time.maghrib,
        isha: time.isha,
      ),
    );
  }
}
