import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/quiet_window.dart';
import 'package:ezanvakti/features/notifications/domain/quiet_window_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 4 Eylül 2026 Cuma; 3 Eylül Perşembe.
  final fridayDhuhr = DateTime(2026, 9, 4, 13, 0);
  final thursdayDhuhr = DateTime(2026, 9, 3, 13, 0);

  QuietMode? modeAt(
    List<QuietWindow> windows,
    DateTime fireAt, {
    PrayerType prayerType = PrayerType.dhuhr,
    DateTime? prayerAt,
  }) => QuietWindowRules.modeFor(
    windows: windows,
    fireAt: fireAt,
    prayerType: prayerType,
    prayerAt: prayerAt ?? fridayDhuhr,
  );

  group('Cuma sablonu', () {
    final windows = [QuietWindow.fridayDefault()];

    test('cuma ogle vaktinde sessiz', () {
      expect(modeAt(windows, fridayDhuhr), QuietMode.silent);
    });

    test('pencere basi ve sonu dahil', () {
      expect(
        modeAt(windows, fridayDhuhr.subtract(const Duration(minutes: 15))),
        QuietMode.silent,
      );
      expect(
        modeAt(windows, fridayDhuhr.add(const Duration(minutes: 60))),
        QuietMode.silent,
      );
    });

    test('pencere disi etkilenmez', () {
      expect(
        modeAt(windows, fridayDhuhr.subtract(const Duration(minutes: 16))),
        isNull,
      );
      expect(
        modeAt(windows, fridayDhuhr.add(const Duration(minutes: 61))),
        isNull,
      );
    });

    test('persembe ogle cuma penceresi degildir', () {
      expect(
        modeAt(windows, thursdayDhuhr, prayerAt: thursdayDhuhr),
        isNull,
      );
    });

    test('cuma ikindi cuma ogle penceresi degildir', () {
      final fridayAsr = DateTime(2026, 9, 4, 16, 30);
      expect(
        modeAt(windows, fridayAsr, prayerType: PrayerType.asr, prayerAt: fridayAsr),
        isNull,
      );
    });

    test('kapali pencere uygulanmaz', () {
      final off = [QuietWindow.fridayDefault().copyWith(isActive: false)];
      expect(modeAt(off, fridayDhuhr), isNull);
    });
  });

  group('vakit bazli pencere', () {
    final windows = [
      QuietWindow(
        id: 'w1',
        trigger: QuietTrigger.prayer,
        prayerType: PrayerType.maghrib,
        minutesBefore: 5,
        minutesAfter: 20,
        mode: QuietMode.skip,
      ),
    ];
    final maghrib = DateTime(2026, 9, 4, 19, 45);

    test('her gun gecerli', () {
      expect(
        modeAt(windows, maghrib, prayerType: PrayerType.maghrib, prayerAt: maghrib),
        QuietMode.skip,
      );
      final monday = DateTime(2026, 9, 7, 19, 45);
      expect(
        modeAt(windows, monday, prayerType: PrayerType.maghrib, prayerAt: monday),
        QuietMode.skip,
      );
    });

    test('baska vakti etkilemez', () {
      expect(modeAt(windows, fridayDhuhr), isNull);
    });
  });

  test('cakisan pencerelerde daha guclu olan (skip) kazanir', () {
    final windows = [
      QuietWindow.fridayDefault(),
      QuietWindow(
        id: 'w2',
        trigger: QuietTrigger.prayer,
        prayerType: PrayerType.dhuhr,
        minutesBefore: 30,
        minutesAfter: 30,
        mode: QuietMode.skip,
      ),
    ];
    expect(modeAt(windows, fridayDhuhr), QuietMode.skip);
  });

  test('JSON round-trip', () {
    final window = QuietWindow.fridayDefault();
    final restored = QuietWindow.fromJson(window.toJson());
    expect(restored.trigger, window.trigger);
    expect(restored.minutesBefore, window.minutesBefore);
    expect(restored.minutesAfter, window.minutesAfter);
    expect(restored.mode, window.mode);
    expect(restored.isActive, window.isActive);
  });
}
