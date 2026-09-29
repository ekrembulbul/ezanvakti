import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/models/prayer_tune_settings.dart';
import 'package:ezanvakti/features/prayer_times/domain/calendar_month_repository.dart';
import 'package:ezanvakti/features/prayer_times/domain/prayer_times_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

const location = Location(id: 'test', province: 'İstanbul', district: 'Fatih');

/// Istenen araligi takvim gunleriyle doner ve her istegi kaydeder.
class RecordingProvider extends FakeProvider {
  final requests = <({DateTime start, DateTime end})>[];

  /// Verilirse aralik yerine bu liste doner (sira ve tekrar testleri, 404).
  List<PrayerTime>? response;

  @override
  Future<List<PrayerTime>> fetchPrayerTimes({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    fetchCount++;
    requests.add((start: startDate, end: endDate));
    final failure = failWith;
    if (failure != null) throw failure;
    final fixed = response;
    if (fixed != null) return fixed;
    return [
      for (
        var day = DateTime(startDate.year, startDate.month, startDate.day);
        !day.isAfter(endDate);
        day = DateTime(day.year, day.month, day.day + 1)
      )
        prayerTimeFor(day),
    ];
  }
}

void main() {
  late FakeStorage storage;
  late RecordingProvider provider;
  late CalendarMonthRepository repository;

  setUp(() {
    storage = FakeStorage();
    provider = RecordingProvider();
    repository = CalendarMonthRepository(
      PrayerTimesRepository(provider: provider, storage: storage),
    );
  });

  test(
    'ayin 1i ile son gununu ister; ay icindeki herhangi bir gun yeter',
    () async {
      final february = await repository.load(
        location: location,
        month: DateTime(2026, 2, 17),
      );
      expect(provider.requests.single, (
        start: DateTime(2026, 2, 1),
        end: DateTime(2026, 2, 28),
      ));
      expect(february.map((t) => t.date).toList(), [
        for (var day = 1; day <= 28; day++) DateTime(2026, 2, day),
      ]);

      final december = await repository.load(
        location: location,
        month: DateTime(2026, 12),
      );
      expect(provider.requests.last, (
        start: DateTime(2026, 12, 1),
        end: DateTime(2026, 12, 31),
      ));
      expect(december, hasLength(31));
    },
  );

  test('forceRefresh onbellegi atlayip saglayiciya gider', () async {
    await repository.load(location: location, month: DateTime(2026, 9));
    await Future<void>.delayed(Duration.zero); // onbellek yazimi kuyrukta
    await repository.load(location: location, month: DateTime(2026, 9));
    expect(provider.fetchCount, 1, reason: 'ikinci okuma onbellekten');

    await repository.load(
      location: location,
      month: DateTime(2026, 9),
      forceRefresh: true,
    );
    expect(provider.fetchCount, 2);
  });

  test(
    'sonuc tarihe gore siralanir, ayni gunun tekrari elenir (ilk gelen kalir)',
    () async {
      final first = prayerTimeFor(DateTime(2026, 9, 1));
      final duplicate = first.copyWith(
        fajr: first.fajr.add(const Duration(minutes: 9)),
      );
      provider.response = [
        prayerTimeFor(DateTime(2026, 9, 3)),
        first,
        prayerTimeFor(DateTime(2026, 9, 2)),
        duplicate,
      ];

      final days = await repository.load(
        location: location,
        month: DateTime(2026, 9),
      );

      expect(days.map((t) => t.date).toList(), [
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 2),
        DateTime(2026, 9, 3),
      ]);
      expect(days.first.fajr, first.fajr);
    },
  );

  test('kullanici duzeltmesi okuma aninda uygulanir (ADR 0004)', () async {
    await storage.savePrayerTuneSettings(
      const PrayerTuneSettings(tune: {PrayerType.fajr: 3}),
    );
    final days = await repository.load(
      location: location,
      month: DateTime(2026, 9),
    );
    expect(days.first.fajr, DateTime(2026, 9, 1, 4, 14));
  });

  test(
    'sunucu yili yayimlamamissa (404) bos liste doner, hata firlatmaz',
    () async {
      provider.response = const [];
      expect(
        await repository.load(location: location, month: DateTime(2027, 3)),
        isEmpty,
      );
    },
  );
}
