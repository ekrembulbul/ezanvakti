import 'package:ezanvakti/core/models/notification_setting.dart'
    show PrayerType;
import 'package:ezanvakti/core/models/quiet_interval.dart';
import 'package:ezanvakti/core/models/quiet_window.dart';
import 'package:ezanvakti/features/notifications/domain/quiet_phone_planner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  // prayerTimeFor: ogle 13:15, yatsi 22:01.
  final friday = DateTime(2026, 10, 9); // Cuma
  final days = [
    for (var i = 0; i < 7; i++) prayerTimeFor(friday.add(Duration(days: i))),
  ];

  QuietWindow window({bool silence = true, bool active = true}) =>
      QuietWindow.fridayDefault().copyWith(
        silencePhone: silence,
        isActive: active,
      );

  test('Cuma penceresi yalniz Cuma ogle cevresinde aralik uretir', () {
    final plan = QuietPhonePlanner.plan(
      windows: [window()],
      prayerTimes: days,
      now: friday,
    );
    expect(plan, [
      QuietInterval(
        DateTime(2026, 10, 9, 13, 0),
        DateTime(2026, 10, 9, 14, 15),
      ),
    ]);
  });

  test('silencePhone kapali ya da pencere pasifse aralik yok', () {
    expect(
      QuietPhonePlanner.plan(
        windows: [window(silence: false)],
        prayerTimes: days,
        now: friday,
      ),
      isEmpty,
    );
    expect(
      QuietPhonePlanner.plan(
        windows: [window(active: false)],
        prayerTimes: days,
        now: friday,
      ),
      isEmpty,
    );
  });

  test('bitmis aralik atilir, suren aralik kalir', () {
    final during = DateTime(2026, 10, 9, 13, 30);
    expect(
      QuietPhonePlanner.plan(
        windows: [window()],
        prayerTimes: days,
        now: during,
      ).single.start,
      DateTime(2026, 10, 9, 13, 0),
    );
    final after = DateTime(2026, 10, 9, 14, 15);
    expect(
      QuietPhonePlanner.plan(
        windows: [window()],
        prayerTimes: days,
        now: after,
      ),
      isEmpty,
    );
  });

  test('cakisan ve gece yarisini asan pencereler birlesir', () {
    const isha = QuietWindow(
      id: 'i',
      trigger: QuietTrigger.prayer,
      prayerType: PrayerType.isha,
      minutesBefore: 0,
      minutesAfter: 180,
      silencePhone: true,
    );
    const isha2 = QuietWindow(
      id: 'j',
      trigger: QuietTrigger.prayer,
      prayerType: PrayerType.isha,
      minutesBefore: 30,
      minutesAfter: 60,
      silencePhone: true,
    );
    final plan = QuietPhonePlanner.plan(
      windows: [isha, isha2],
      prayerTimes: days.take(1).toList(),
      now: friday,
    );
    expect(plan, [
      QuietInterval(
        DateTime(2026, 10, 9, 21, 31),
        DateTime(2026, 10, 10, 1, 1),
      ),
    ]);
  });

  test('sifir uzunluklu pencere aralik uretmez', () {
    const zero = QuietWindow(
      id: 'z',
      trigger: QuietTrigger.prayer,
      prayerType: PrayerType.asr,
      minutesBefore: 0,
      minutesAfter: 0,
      silencePhone: true,
    );
    expect(
      QuietPhonePlanner.plan(windows: [zero], prayerTimes: days, now: friday),
      isEmpty,
    );
  });
}
