import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/features/ramadan/domain/ramadan_countdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PrayerTime dayAt(DateTime date) => PrayerTime(
    date: DateTime(date.year, date.month, date.day),
    fajr: DateTime(date.year, date.month, date.day, 5, 30),
    sunrise: DateTime(date.year, date.month, date.day, 7, 0),
    dhuhr: DateTime(date.year, date.month, date.day, 13, 0),
    asr: DateTime(date.year, date.month, date.day, 16, 0),
    maghrib: DateTime(date.year, date.month, date.day, 18, 30),
    isha: DateTime(date.year, date.month, date.day, 20, 0),
  );

  final today = dayAt(DateTime(2027, 2, 20));
  final tomorrow = dayAt(DateTime(2027, 2, 21));

  test('imsaktan once: sahurun bitisine sayilir', () {
    final target = RamadanCountdown.resolve(
      now: DateTime(2027, 2, 20, 4, 0),
      today: today,
      tomorrow: tomorrow,
    );
    expect(target!.kind, RamadanCountdownKind.suhoor);
    expect(target.time, today.fajr);
  });

  test('gunduz: iftara sayilir', () {
    final target = RamadanCountdown.resolve(
      now: DateTime(2027, 2, 20, 12, 0),
      today: today,
      tomorrow: tomorrow,
    );
    expect(target!.kind, RamadanCountdownKind.iftar);
    expect(target.time, today.maghrib);
  });

  test('iftardan sonra: ertesi sahura sayilir', () {
    final target = RamadanCountdown.resolve(
      now: DateTime(2027, 2, 20, 19, 0),
      today: today,
      tomorrow: tomorrow,
    );
    expect(target!.kind, RamadanCountdownKind.suhoor);
    expect(target.time, tomorrow.fajr);
  });

  test('ertesi gun verisi yoksa iftardan sonra hedef yok', () {
    final target = RamadanCountdown.resolve(
      now: DateTime(2027, 2, 20, 19, 0),
      today: today,
      tomorrow: null,
    );
    expect(target, isNull);
  });

  test('tam imsak aninda gunduze gecer', () {
    final target = RamadanCountdown.resolve(
      now: today.fajr,
      today: today,
      tomorrow: tomorrow,
    );
    expect(target!.kind, RamadanCountdownKind.iftar);
  });
}
