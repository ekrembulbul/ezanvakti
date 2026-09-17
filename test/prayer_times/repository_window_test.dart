import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/features/prayer_times/domain/prayer_times_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// Yilin tamamini donen saglayici (DiyanetProvider gibi).
class YearProvider extends FakeProvider {
  @override
  Future<List<PrayerTime>> fetchPrayerTimes({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    fetchCount++;
    return List.generate(365, (i) => prayerTimeFor(DateTime(2026, 1, 1 + i)));
  }
}

void main() {
  test(
    'depo saglayicinin tum gunlerini onbellege yazar, yalniz pencereyi doner',
    () async {
      final storage = FakeStorage();
      final repo = PrayerTimesRepository(
        provider: YearProvider(),
        storage: storage,
      );
      const loc = Location(
        id: 'diyanet-9547',
        province: 'İstanbul',
        district: 'Şile',
        cityId: 9547,
      );
      final result = await repo.getPrayerTimes(
        location: loc,
        startDate: DateTime(2026, 9, 15),
        endDate: DateTime(2026, 9, 17),
      );
      expect(result.map((t) => t.date), [
        DateTime(2026, 9, 15),
        DateTime(2026, 9, 16),
        DateTime(2026, 9, 17),
      ]);
      await Future<void>.delayed(Duration.zero); // onbellek yazimi kuyrukta
      final cached = await storage.getPrayerTimes(
        locationId: loc.id,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
      );
      expect(cached, hasLength(365));
    },
  );
}
