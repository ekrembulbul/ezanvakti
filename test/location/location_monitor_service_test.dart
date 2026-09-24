import 'dart:convert';

import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/features/location/data/gps_location_service.dart';
import 'package:ezanvakti/features/location/data/places_api.dart';
import 'package:ezanvakti/features/location/domain/location_monitor_service.dart';
import 'package:ezanvakti/features/location/domain/location_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fakes.dart';

/// Uygulama her acildiginda GPS akisindan ilk fix gelir. Referans koordinat
/// kayitli konumdan tohumlandigi icin, kullanici gercekten tasinmadikca bu fix
/// "onemli degisim" sayilmamalidir.
void main() {
  const istanbul = (latitude: 41.008, longitude: 28.978);
  final now = DateTime(2026, 8, 3, 12);

  test('Referans yokken ilk fix onemli sayilir', () {
    expect(
      isSignificantLocationChange(
        previous: null,
        current: istanbul,
        lastUpdate: null,
        now: now,
      ),
      isTrue,
    );
  });

  test('Ayni yerdeki ilk fix onemli sayilmaz', () {
    // 50 metre sapma: GPS gurultusu, tasinma degil.
    const nearby = (latitude: 41.0084, longitude: 28.9785);

    expect(
      isSignificantLocationChange(
        previous: istanbul,
        current: nearby,
        lastUpdate: null,
        now: now,
      ),
      isFalse,
    );
  });

  test('Bes kilometreden uzak fix onemli sayilir', () {
    // ~11 km kuzey.
    const faraway = (latitude: 41.108, longitude: 28.978);

    expect(
      isSignificantLocationChange(
        previous: istanbul,
        current: faraway,
        lastUpdate: null,
        now: now,
      ),
      isTrue,
    );
  });

  test('Son guncellemeden bu yana 30 dakika gecmediyse onemli sayilmaz', () {
    const faraway = (latitude: 41.108, longitude: 28.978);

    expect(
      isSignificantLocationChange(
        previous: istanbul,
        current: faraway,
        lastUpdate: now.subtract(const Duration(minutes: 5)),
        now: now,
      ),
      isFalse,
    );
  });

  group('handleFix', () {
    const headers = {'content-type': 'application/json; charset=utf-8'};
    Map<String, dynamic> city(int id, String name, String state) => {
      'id': id,
      'name': name,
      'stateName': state,
      'displayName': '$name, $state',
      'stateId': 539,
      'countryId': 2,
      'isCentre': false,
      'latitude': 41.17,
      'longitude': 29.61,
    };
    http.Response resolved(Map<String, dynamic> c) => http.Response(
      jsonEncode({'city': c, 'distanceKm': 1.2}),
      200,
      headers: headers,
    );
    const sile = Location(
      id: 'gps',
      province: 'İstanbul',
      district: 'Şile',
      type: LocationType.gps,
      cityId: 9547,
      latitude: 41.17,
      longitude: 29.61,
    );
    final at = DateTime(2026, 9, 17, 12);

    late FakeStorage storage;
    late List<String> cleared;
    late List<Location> events;

    LocationMonitorService service(
      Future<http.Response> Function(http.Request) handler,
    ) {
      final repo = LocationRepository(
        storage: storage,
        clearPrayerCache: (id) async => cleared.add(id),
      );
      final monitor = LocationMonitorService(
        locationRepository: repo,
        gps: GpsLocationService(
          api: PlacesApi(
            client: MockClient(handler),
            baseUrl: 'https://api.test',
          ),
        ),
      );
      monitor.onLocationChanged.listen(events.add);
      return monitor;
    }

    setUp(() async {
      storage = FakeStorage();
      cleared = [];
      events = [];
      await storage.saveLocation(sile);
      await storage.saveActiveLocation(sile);
    });

    test(
      'ilce degisince konum guncellenir, onbellek temizlenir, olay yayilir',
      () async {
        final monitor = service(
          (_) async => resolved(city(9206, 'Ankara', 'Ankara')),
        );
        await monitor.handleFix((latitude: 39.9, longitude: 32.8), now: at);
        await Future<void>.delayed(Duration.zero);

        final gps = (await storage.getSavedLocations()).single;
        expect(gps.cityId, 9206);
        expect(gps.latitude, 39.9);
        expect(gps.type, LocationType.gps);
        expect(cleared, ['gps']);
        expect(events.single.cityId, 9206);
      },
    );

    test(
      'ayni ilcede yalniz koordinat yazilir; olay ve temizlik yok',
      () async {
        final monitor = service(
          (_) async => resolved(city(9547, 'Şile', 'İstanbul')),
        );
        await monitor.handleFix((latitude: 41.2, longitude: 29.7), now: at);
        await Future<void>.delayed(Duration.zero);

        final gps = (await storage.getSavedLocations()).single;
        expect(gps.cityId, 9547);
        expect(gps.latitude, 41.2);
        expect((await storage.getActiveLocation())!.latitude, 41.2);
        expect(cleared, isEmpty);
        expect(events, isEmpty);
      },
    );

    test('kapsama disi fix eski ilceyi korur', () async {
      final monitor = service(
        (_) async => http.Response(
          '{"error":{"code":"NO_COVERAGE","message":"x"}}',
          404,
          headers: headers,
        ),
      );
      await monitor.handleFix((latitude: 48.85, longitude: 2.35), now: at);

      expect((await storage.getSavedLocations()).single.cityId, 9547);
      expect(events, isEmpty);
    });

    test(
      'ag hatasinda deneme atlanir, referans guncellenmez (sonraki fix dener)',
      () async {
        var calls = 0;
        final monitor = service((_) async {
          calls++;
          return http.Response('', 503);
        });
        await monitor.handleFix((latitude: 39.9, longitude: 32.8), now: at);
        await monitor.handleFix((
          latitude: 39.9,
          longitude: 32.8,
        ), now: at.add(const Duration(minutes: 1)));

        expect(
          calls,
          2,
          reason: 'referans kaydedilmedigi icin ikinci fix de denenir',
        );
        expect((await storage.getSavedLocations()).single.cityId, 9547);
        expect(cleared, isEmpty);
      },
    );
  });
}
