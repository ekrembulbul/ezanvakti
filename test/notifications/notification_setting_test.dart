import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/presentation/services/upcoming_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const daily = NotificationSetting(
    prayerType: PrayerType.dhuhr,
    isActive: true,
    minutesBefore: 45,
  );
  const friday = NotificationSetting(
    prayerType: PrayerType.dhuhr,
    isActive: true,
    minutesBefore: 45,
    weekdays: {5},
    label: 'Cuma namazı',
  );

  test('notificationKey gunleri de kapsar', () {
    expect(notificationKey(daily), isNot(notificationKey(friday)));
    expect(notificationKey(daily), 'dhuhr-45-');
    expect(notificationKey(friday), 'dhuhr-45-5');
  });

  test('firesOnWeekday: bos kume her gun demek', () {
    expect(daily.firesOnWeekday(3), isTrue);
    expect(friday.firesOnWeekday(3), isFalse);
    expect(friday.firesOnWeekday(5), isTrue);
  });

  test('esitlik yeni alanlari kapsar', () {
    expect(daily == friday, isFalse);
    expect(
      friday,
      const NotificationSetting(
        prayerType: PrayerType.dhuhr,
        isActive: true,
        minutesBefore: 45,
        weekdays: {5},
        label: 'Cuma namazı',
      ),
    );
  });

  test('JSON round-trip yeni alanlari korur', () {
    final restored = NotificationSetting.fromJson(friday.toJson());
    expect(restored.weekdays, {5});
    expect(restored.label, 'Cuma namazı');
    expect(restored.soundId, isNull);
  });

  test('copyWith gunleri ve etiketi degistirebilir', () {
    final updated = daily.copyWith(weekdays: const {1, 2}, soundId: 'beep');
    expect(updated.weekdays, {1, 2});
    expect(updated.soundId, 'beep');
    expect(updated.minutesBefore, daily.minutesBefore);
  });
}
