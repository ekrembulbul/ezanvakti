import 'dart:convert';

import 'package:ezanvakti/core/models/hijri_date.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/features/prayer_times/data/diyanet_provider.dart';
import 'package:ezanvakti/features/prayer_times/domain/prayer_times_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fakes.dart';

const sile = Location(
  id: 'diyanet-9547',
  province: 'İstanbul',
  district: 'Şile',
  cityId: 9547,
  stateId: 539,
  countryId: 2,
);

const jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> day(String date, int hDay, int hMonth, int hYear) => {
  'date': date,
  'hijri': {'day': hDay, 'month': hMonth, 'year': hYear, 'monthName': 'x'},
  'fajr': '05:11',
  'sunrise': '06:37',
  'dhuhr': '13:04',
  'asr': '16:35',
  'maghrib': '19:22',
  'isha': '20:43',
  'astronomicalSunrise': null,
  'astronomicalSunset': null,
  'qiblaTime': null,
  'gmtOffset': 3,
};

String yearBody(int year, List<Map<String, dynamic>> days) => jsonEncode({
  'schemaVersion': 1,
  'source': 'diyanet',
  'generatedAt': '2026-09-17T00:00:00Z',
  'cityId': 9547,
  'year': year,
  'complete': days.length >= 365,
  'days': days,
});

void main() {
  late FakeStorage storage;
  setUp(() => storage = FakeStorage());

  DiyanetProvider provider(
    Future<http.Response> Function(http.Request) handler,
  ) => DiyanetProvider(
    client: MockClient(handler),
    storage: storage,
    baseUrl: 'https://api.test',
  );

  test(
    'yilin gunlerini HH:MM ve Hicri ile PrayerTime yapar, ETag saklar',
    () async {
      final requests = <http.Request>[];
      final p = provider((req) async {
        requests.add(req);
        return http.Response(
          yearBody(2026, [
            day('2026-09-15', 4, 4, 1448),
            day('2026-09-16', 5, 4, 1448),
          ]),
          200,
          headers: {...jsonHeaders, 'etag': '"abc"'},
        );
      });
      final times = await p.fetchPrayerTimes(
        location: sile,
        startDate: DateTime(2026, 9, 15),
        endDate: DateTime(2026, 9, 15),
      );
      expect(
        requests.single.url.toString(),
        'https://api.test/v1/prayer-times/9547/2026',
      );
      expect(
        times,
        hasLength(2),
        reason: 'saglayici yilin tamamini doner; pencereyi depo keser',
      );
      expect(times.first.date, DateTime(2026, 9, 15));
      expect(times.first.maghrib, DateTime(2026, 9, 15, 19, 22));
      expect(times.first.hijri, const HijriDate(day: 4, month: 4, year: 1448));
      expect(await storage.getSetting('etag:9547:2026'), '"abc"');
    },
  );

  test('If-None-Match gonderir; 304te onbellekteki yili doner', () async {
    await storage.setSetting('etag:9547:2026', '"abc"');
    await storage.savePrayerTimes([
      prayerTimeFor(DateTime(2026, 9, 15)),
    ], sile.id);
    late http.Request seen;
    final p = provider((req) async {
      seen = req;
      return http.Response('', 304);
    });
    final times = await p.fetchPrayerTimes(
      location: sile,
      startDate: DateTime(2026, 9, 15),
      endDate: DateTime(2026, 9, 15),
    );
    expect(
      seen.headers['If-None-Match'] ?? seen.headers['if-none-match'],
      '"abc"',
    );
    expect(times, hasLength(1));
  });

  test('pencere iki yila yayilirsa iki istek', () async {
    final years = <String>[];
    final p = provider((req) async {
      years.add(req.url.pathSegments.last);
      final y = int.parse(req.url.pathSegments.last);
      return http.Response(
        yearBody(y, [day('$y-01-01', 1, 1, 1448)]),
        200,
        headers: jsonHeaders,
      );
    });
    await p.fetchPrayerTimes(
      location: sile,
      startDate: DateTime(2026, 12, 28),
      endDate: DateTime(2027, 1, 5),
    );
    expect(years, ['2026', '2027']);
  });

  test('404: yil yayinlanmamis → bos liste', () async {
    final p = provider(
      (_) async =>
          http.Response('{"error":{"code":"NOT_FOUND","message":"x"}}', 404),
    );
    expect(
      await p.fetchPrayerTimes(
        location: sile,
        startDate: DateTime(2028, 1, 1),
        endDate: DateTime(2028, 1, 2),
      ),
      isEmpty,
    );
  });

  test('cityId olmayan konum LocationNotMappedException', () async {
    final p = provider((_) async => http.Response('', 200));
    expect(
      () => p.fetchPrayerTimes(
        location: const Location(id: 'x', province: 'a', district: 'b'),
        startDate: DateTime(2026),
        endDate: DateTime(2026),
      ),
      throwsA(isA<LocationNotMappedException>()),
    );
  });

  test('5xx uc denemeden sonra basarili yanit alinir', () async {
    var calls = 0;
    final p = provider((_) async {
      calls++;
      if (calls < 3) return http.Response('boom', 503);
      return http.Response(
        yearBody(2026, [day('2026-09-15', 4, 4, 1448)]),
        200,
        headers: jsonHeaders,
      );
    });
    final times = await p.fetchPrayerTimes(
      location: sile,
      startDate: DateTime(2026, 9, 15),
      endDate: DateTime(2026, 9, 15),
    );
    expect(times, hasLength(1));
    expect(calls, 3);
  });

  group('304 yalniz bu konumun onbellegi pencereyi tutuyorsa', () {
    const gps = Location(
      id: 'gps',
      province: 'İstanbul',
      district: 'Şile',
      type: LocationType.gps,
      cityId: 9547,
      stateId: 539,
      countryId: 2,
    );
    final start = DateTime(2026, 9, 23);
    final end = DateTime(2026, 10, 5);

    // Sunucu gibi: ETag eslesirse 304, degilse yilin tamami + ETag.
    Future<http.Response> Function(http.Request) etagServer(
      List<http.Request> seen,
    ) => (req) async {
      seen.add(req);
      if (req.headers['If-None-Match'] == '"v1"') {
        return http.Response('', 304, headers: {'etag': '"v1"'});
      }
      return http.Response(
        yearBody(2026, [
          for (
            var d = DateTime(2026, 1, 1);
            d.year == 2026;
            d = DateTime(d.year, d.month, d.day + 1)
          )
            day(d.toIso8601String().substring(0, 10), 4, 4, 1448),
        ]),
        200,
        headers: {...jsonHeaders, 'etag': '"v1"'},
      );
    };

    test('ayni ilcenin ikinci konumu (GPS) kosulsuz ister', () async {
      final seen = <http.Request>[];
      final p = provider(etagServer(seen));
      await p.fetchPrayerTimes(location: sile, startDate: start, endDate: end);

      final times = await p.fetchPrayerTimes(
        location: gps,
        startDate: start,
        endDate: end,
      );
      expect(seen.last.headers['If-None-Match'], isNull);
      expect(times, hasLength(365));
    });

    test('yeniden eklenen konum (onbellegi silinir) vakitleri alir', () async {
      final seen = <http.Request>[];
      final repo = PrayerTimesRepository(
        provider: provider(etagServer(seen)),
        storage: storage,
      );
      Future<List<PrayerTime>> load() =>
          repo.getPrayerTimes(location: sile, startDate: start, endDate: end);

      expect(await load(), hasLength(13));
      await repo.clearCacheForLocation(sile.id); // konum ekleme ekrani
      expect(await load(), hasLength(13));
    });

    test('onbellek pencerenin bir kismini tutuyorsa kosulsuz ister', () async {
      await storage.setSetting('etag:9547:2026', '"v1"');
      await storage.savePrayerTimes([prayerTimeFor(start)], sile.id);
      final seen = <http.Request>[];
      final times = await provider(
        etagServer(seen),
      ).fetchPrayerTimes(location: sile, startDate: start, endDate: end);
      expect(seen.single.headers['If-None-Match'], isNull);
      expect(times, hasLength(365));
    });
  });

  test('fetchDailyPrayerTime gunu doner, yoksa null', () async {
    final p = provider(
      (_) async => http.Response(
        yearBody(2026, [day('2026-09-15', 4, 4, 1448)]),
        200,
        headers: jsonHeaders,
      ),
    );
    final t = await p.fetchDailyPrayerTime(
      location: sile,
      date: DateTime(2026, 9, 15, 10),
    );
    expect(t?.date, DateTime(2026, 9, 15));
    expect(
      await p.fetchDailyPrayerTime(location: sile, date: DateTime(2026, 9, 16)),
      isNull,
    );
  });
}
