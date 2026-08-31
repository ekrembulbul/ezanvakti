import 'package:ezanvakti/core/models/notification_setting.dart' show PrayerType;
import 'package:ezanvakti/core/models/calculation_settings.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/features/prayer_times/domain/prayer_time_tuner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = PrayerTime(
    date: DateTime(2026, 8, 31),
    fajr: DateTime(2026, 8, 31, 5, 0),
    sunrise: DateTime(2026, 8, 31, 6, 30),
    dhuhr: DateTime(2026, 8, 31, 13, 0),
    asr: DateTime(2026, 8, 31, 16, 30),
    maghrib: DateTime(2026, 8, 31, 19, 45),
    isha: DateTime(2026, 8, 31, 21, 15),
  );

  test('tune dakikalari her vakte ayri uygulanir, tarih degismez', () {
    final tuned = PrayerTimeTuner.applyOne(base, const {
      PrayerType.fajr: -2,
      PrayerType.isha: 3,
    });
    expect(tuned.fajr, base.fajr.subtract(const Duration(minutes: 2)));
    expect(tuned.isha, base.isha.add(const Duration(minutes: 3)));
    expect(tuned.dhuhr, base.dhuhr);
    expect(tuned.date, base.date);
  });

  test('bos tune ayni nesneyi dondurur', () {
    expect(PrayerTimeTuner.applyOne(base, const {}), same(base));
    expect(PrayerTimeTuner.apply(const [], const {}), isEmpty);
  });

  test('sifir degerler etkisiz', () {
    final tuned = PrayerTimeTuner.applyOne(base, const {PrayerType.asr: 0});
    expect(tuned.asr, base.asr);
  });

  test('CalculationSettings tune JSON round-trip: sifirlar yazilmaz', () {
    const settings = CalculationSettings(
      method: 13,
      school: 0,
      tune: {PrayerType.fajr: -2, PrayerType.asr: 0},
    );
    final json = settings.toJson();
    expect((json['tune'] as Map).containsKey('asr'), isFalse);
    final restored = CalculationSettings.fromJson(json);
    expect(restored.tune, {PrayerType.fajr: -2});
    expect(restored, settings.copyWith(tune: const {PrayerType.fajr: -2}));
  });

  test('liste hali her gune uygular', () {
    final second = base.copyWith(date: DateTime(2026, 9, 1));
    final tuned = PrayerTimeTuner.apply([base, second], const {
      PrayerType.maghrib: 1,
    });
    expect(tuned, hasLength(2));
    expect(tuned[1].maghrib, second.maghrib.add(const Duration(minutes: 1)));
  });
}
