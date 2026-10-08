import 'package:intl/intl.dart';

import '../../../core/models/location.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/utils/hijri_formatter.dart';
import '../../prayer_times/domain/day_ruler_math.dart';
import '../../prayer_times/domain/kerahat_times.dart';
import 'widget_snapshot.dart';
import 'widget_timeline_builder.dart';

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
    WidgetLabels? labels,
    AppLocalizations? l10n,
  }) {
    final today = DateTime(now.year, now.month, now.day);

    final upcoming =
        prayerTimes.where((time) => !_dayOf(time.date).isBefore(today)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final window = upcoming.take(maxDays).toList();

    return WidgetSnapshot(
      locationLabel: location.displayName,
      generatedAt: now,
      days: window.map((time) => _toDay(time, l10n)).toList(),
      labels: labels,
      timeline: WidgetTimelineBuilder.build(days: window, now: now),
    );
  }

  static DateTime _dayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static WidgetSnapshotDay _toDay(PrayerTime time, AppLocalizations? l10n) {
    final day = _dayOf(time.date);
    return WidgetSnapshotDay(
      date: day,
      hijri: time.hijri == null
          ? null
          : HijriFormatter.formatHijri(time.hijri!, l10n),
      times: WidgetDayTimes(
        fajr: time.fajr,
        sunrise: time.sunrise,
        dhuhr: time.dhuhr,
        asr: time.asr,
        maghrib: time.maghrib,
        isha: time.isha,
      ),
      // Ana ekranla aynı hesap; widget kendi başına sabit tutmaz.
      kerahat: [
        for (final interval in KerahatTimes.forDay(time))
          WidgetKerahatInterval(start: interval.start, end: interval.end),
      ],
      weekday: _format('EEEE', day, l10n),
      dateLabel: _format('d MMMM', day, l10n),
      hijriShort: time.hijri == null
          ? null
          : HijriFormatter.formatHijriShort(time.hijri!, l10n),
      ruler: _ruler(time),
    );
  }

  /// Uygulamanın dilinde tarih metni. Yerel ayar verisi yüklenmemişse
  /// (test, erken açılış) alan yazılmaz; widget eski biçime düşer.
  static String? _format(String pattern, DateTime day, AppLocalizations? l10n) {
    try {
      return DateFormat(pattern, l10n?.localeName ?? 'tr').format(day);
    } catch (_) {
      return null;
    }
  }

  /// Ana ekran cetvelinin aynı parçalaması: gündüz İmsak → Akşam, vakit
  /// sınırlarında boşluk, kerahat aralıkları.
  static WidgetRuler _ruler(PrayerTime time) {
    final marks = [
      for (final mark in [
        time.fajr,
        time.sunrise,
        time.dhuhr,
        time.asr,
        time.maghrib,
        time.isha,
      ])
        dayProgress(time, mark),
    ];
    return WidgetRuler(
      segments: buildRulerSegments(
        prayerFractions: marks,
        dayStart: marks[0],
        dayEnd: marks[4],
        kerahatRanges: [
          for (final interval in KerahatTimes.forDay(time))
            (
              start: dayProgress(time, interval.start),
              end: dayProgress(time, interval.end),
            ),
        ],
      ),
      marks: marks,
    );
  }
}
