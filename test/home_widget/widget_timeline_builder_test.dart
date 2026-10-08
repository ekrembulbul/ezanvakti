import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/features/home_widget/domain/widget_snapshot.dart';
import 'package:ezanvakti/features/home_widget/domain/widget_timeline_builder.dart';
import 'package:ezanvakti/features/prayer_times/domain/kerahat_status.dart';
import 'package:ezanvakti/features/prayer_times/domain/kerahat_times.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  // prayerTimeFor: İmsak 04:11, Güneş 05:55, Öğle 13:15, İkindi 17:09,
  // Akşam 20:25, Yatsı 22:01.
  final day1 = prayerTimeFor(DateTime(2026, 10, 8));
  final day2 = prayerTimeFor(DateTime(2026, 10, 9));

  test('her an sıradaki vakti, günü ve kerahat durumunu taşır', () {
    final entries = WidgetTimelineBuilder.build(
      days: [day1, day2],
      now: DateTime(2026, 10, 8, 11),
    );

    final first = entries.first;
    expect(first.at, DateTime(2026, 10, 8, 11));
    expect((first.day, first.slot, first.tomorrow), (0, 2, false));
    expect(first.phase, DayPhase.morning);

    final afterIsha = entries.firstWhere((e) => e.at == day1.isha);
    expect((afterIsha.day, afterIsha.slot, afterIsha.tomorrow), (1, 0, true));
    expect(afterIsha.phase, DayPhase.night);

    final noon = KerahatTimes.forDay(
      day1,
    ).firstWhere((interval) => interval.end == day1.dhuhr);
    final approaching = entries.firstWhere(
      (e) => e.at == noon.start.subtract(KerahatWarning.lead),
    );
    expect(approaching.kerahat?.state, WidgetKerahatState.approaching);
    expect(approaching.kerahat?.start, noon.start);
    expect(approaching.kerahat?.end, noon.end);
    final active = entries.firstWhere((e) => e.at == noon.start);
    expect(active.kerahat?.state, WidgetKerahatState.active);
    // Bitiş = Öğle: o anda kerahat biter, sıradaki vakit İkindi olur.
    final atDhuhr = entries.firstWhere((e) => e.at == day1.dhuhr);
    expect(atDhuhr.kerahat, isNull);
    expect(atDhuhr.slot, 3);
  });

  test('anlar sıralı ve tekil; şimdiden başlar, son vakitten önce biter', () {
    final entries = WidgetTimelineBuilder.build(
      days: [day1],
      now: DateTime(2026, 10, 8, 3),
    );
    final ats = entries.map((e) => e.at).toList();

    expect(ats, [...ats]..sort());
    expect(ats.toSet().length, ats.length);
    expect(ats.first, DateTime(2026, 10, 8, 3));
    expect(ats.last.isBefore(day1.isha), isTrue);
    expect(entries.last.slot, 5);
  });

  test('gece yarısı anı çizelgede yer alır; gece dilimi sürer', () {
    final entries = WidgetTimelineBuilder.build(
      days: [day1, day2],
      now: DateTime(2026, 10, 8, 23, 30),
    );

    expect(entries.first.tomorrow, isTrue);
    final midnight = entries.firstWhere((e) => e.at == DateTime(2026, 10, 9));
    expect(midnight.phase, DayPhase.night);
    expect((midnight.day, midnight.slot, midnight.tomorrow), (1, 0, false));
  });

  test('son vakitten sonra ya da veri yokken çizelge boş', () {
    expect(
      WidgetTimelineBuilder.build(days: [day1], now: DateTime(2026, 10, 8, 23)),
      isEmpty,
    );
    expect(
      WidgetTimelineBuilder.build(days: const [], now: DateTime(2026)),
      isEmpty,
    );
  });

  test('JSON sözleşmesi: epoch milisaniye ve durum adı', () {
    final entry = WidgetTimelineBuilder.build(
      days: [day1],
      now: DateTime(2026, 10, 8, 12, 50),
    ).first;
    final json = entry.toJson();

    expect(json['at'], DateTime(2026, 10, 8, 12, 50).millisecondsSinceEpoch);
    expect(json['phase'], 'morning');
    expect((json['kerahat'] as Map)['state'], 'approaching');
  });
}
