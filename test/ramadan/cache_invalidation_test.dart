import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/features/prayer_times/domain/prayer_times_repository.dart';
import '../support/fakes.dart';

const location = Location(id: 'test', province: 'İstanbul', district: 'Fatih');
final date = DateTime(2026, 2, 19);

class DelayedProvider extends FakeProvider {
  final pending = Completer<List<PrayerTime>>();
  final started = Completer<void>();
  @override
  Future<List<PrayerTime>> fetchPrayerTimes({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    started.complete();
    return pending.future;
  }
}

class DelayedStorage extends FakeStorage {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> savePrayerTimes(List<PrayerTime> times, String id) async {
    if (!started.isCompleted) {
      started.complete();
      await release.future;
    }
    await super.savePrayerTimes(times, id);
  }
}

void main() {
  test('complete cache walks calendar dates across DST', () async {
    final storage = FakeStorage();
    final provider = FakeProvider();
    final repository = PrayerTimesRepository(
      provider: provider,
      storage: storage,
    );
    final start = DateTime(2026, 3, 28);
    final end = DateTime(2026, 3, 30);
    await storage.savePrayerTimes([
      for (var d = 28; d <= 30; d++) prayerTimeFor(DateTime(2026, 3, d)),
    ], location.id);
    final result = await repository.getPrayerTimes(
      location: location,
      startDate: start,
      endDate: end,
    );
    expect(result.length, 3);
    expect(provider.fetchCount, 0);
  });
  test('invalidation prevents an old fetch from repopulating cache', () async {
    final provider = DelayedProvider();
    final storage = FakeStorage();
    final repository = PrayerTimesRepository(
      provider: provider,
      storage: storage,
    );
    final request = repository.getPrayerTimes(
      location: location,
      startDate: date,
      endDate: date,
    );
    await provider.started.future;
    await repository.clearAllCache();
    provider.pending.complete([prayerTimeFor(date)]);
    await request;
    expect(
      await storage.getDailyPrayerTime(locationId: location.id, date: date),
      isNull,
    );
  });

  test(
    'invalidation waits for a started write then clears it; new data survives',
    () async {
      final storage = DelayedStorage();
      final repository = PrayerTimesRepository(
        provider: FakeProvider(),
        storage: storage,
      );
      final request = repository.getDailyPrayerTime(
        location: location,
        date: date,
      );
      await storage.started.future;
      final clear = repository.clearCacheForLocation(location.id);
      storage.release.complete();
      await Future.wait([request, clear]);
      expect(
        await storage.getDailyPrayerTime(locationId: location.id, date: date),
        isNull,
      );
      await repository.getDailyPrayerTime(location: location, date: date);
      expect(
        await storage.getDailyPrayerTime(locationId: location.id, date: date),
        isNotNull,
      );
    },
  );
}
