import 'package:ezanvakti/core/models/derived_time.dart';
import 'package:ezanvakti/core/models/notification_setting.dart' show PrayerType;
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/features/prayer_times/domain/derived_times.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PrayerTime dayAt(DateTime date) => PrayerTime(
    date: DateTime(date.year, date.month, date.day),
    fajr: DateTime(date.year, date.month, date.day, 5, 0),
    sunrise: DateTime(date.year, date.month, date.day, 6, 30),
    dhuhr: DateTime(date.year, date.month, date.day, 13, 0),
    asr: DateTime(date.year, date.month, date.day, 16, 30),
    maghrib: DateTime(date.year, date.month, date.day, 19, 45),
    isha: DateTime(date.year, date.month, date.day, 21, 15),
  );

  final day = dayAt(DateTime(2026, 9, 4));
  final tomorrow = dayAt(DateTime(2026, 9, 5));

  test('israk gunesten 45 dk sonra', () {
    expect(
      DerivedTimes.resolve(kind: DerivedTimeKind.ishraq, day: day),
      day.sunrise.add(const Duration(minutes: 45)),
    );
  });

  test('istiva ogleden 10 dk once', () {
    expect(
      DerivedTimes.resolve(kind: DerivedTimeKind.istiwa, day: day),
      day.dhuhr.subtract(const Duration(minutes: 10)),
    );
  });

  test('aksam oncesi kerahat aksamdan 45 dk once', () {
    expect(
      DerivedTimes.resolve(kind: DerivedTimeKind.preMaghrib, day: day),
      day.maghrib.subtract(const Duration(minutes: 45)),
    );
  });

  test('gece yarisi aksam ile ertesi imsagin ortasi', () {
    final night = tomorrow.fajr.difference(day.maghrib);
    expect(
      DerivedTimes.resolve(
        kind: DerivedTimeKind.midnight,
        day: day,
        nextDay: tomorrow,
      ),
      day.maghrib.add(night ~/ 2),
    );
  });

  test('son ucte bir ertesi imsaktan gecenin ucte biri once', () {
    final night = tomorrow.fajr.difference(day.maghrib);
    expect(
      DerivedTimes.resolve(
        kind: DerivedTimeKind.lastThird,
        day: day,
        nextDay: tomorrow,
      ),
      tomorrow.fajr.subtract(night ~/ 3),
    );
  });

  test('ertesi gun yoksa gece vakitleri hesaplanmaz', () {
    expect(
      DerivedTimes.resolve(kind: DerivedTimeKind.midnight, day: day),
      isNull,
    );
    expect(
      DerivedTimes.resolve(kind: DerivedTimeKind.lastThird, day: day),
      isNull,
    );
  });

  test('gunduz vakitleri ertesi gun olmadan da hesaplanir', () {
    for (final kind in [
      DerivedTimeKind.ishraq,
      DerivedTimeKind.istiwa,
      DerivedTimeKind.preMaghrib,
    ]) {
      expect(DerivedTimes.resolve(kind: kind, day: day), isNotNull, reason: kind.name);
    }
  });

  test('ayarlanabilir sabitler uygulanir', () {
    expect(
      DerivedTimes.resolve(
        kind: DerivedTimeKind.ishraq,
        day: day,
        settings: const DerivedTimeSettings(ishraqMinutes: 30),
      ),
      day.sunrise.add(const Duration(minutes: 30)),
    );
  });

  test('her turetilmis noktanin bir cipa vakti var', () {
    expect(DerivedTimeKind.ishraq.anchor, PrayerType.sunrise);
    expect(DerivedTimeKind.istiwa.anchor, PrayerType.dhuhr);
    expect(DerivedTimeKind.preMaghrib.anchor, PrayerType.maghrib);
    expect(DerivedTimeKind.midnight.anchor, PrayerType.maghrib);
    expect(DerivedTimeKind.lastThird.anchor, PrayerType.maghrib);
  });

  test('depolama degerleri kararli', () {
    for (final kind in DerivedTimeKind.values) {
      expect(DerivedTimeKindX.fromStorage(kind.storageValue), kind);
    }
    expect(DerivedTimeKindX.fromStorage(null), isNull);
    expect(DerivedTimeKindX.fromStorage('bilinmeyen'), isNull);
  });
}
