import 'dart:convert';

import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/features/location/data/places_api.dart';
import 'package:ezanvakti/features/location/domain/location_migration_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fakes.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> match(
  int id,
  String name,
  String state, {
  bool centre = false,
  String? alias,
  double lat = 41.0,
  double lon = 29.0,
}) => {
  'id': id,
  'name': name,
  'stateName': state,
  'displayName': centre ? '$name (Merkez)' : '$name, $state',
  'stateId': 539,
  'countryId': 2,
  'isCentre': centre,
  'latitude': lat,
  'longitude': lon,
  'qiblaAngle': 150.0,
  'matchedAlias': ?alias,
};

void main() {
  late FakeStorage storage;
  late List<String> cleared;

  setUp(() {
    storage = FakeStorage();
    cleared = [];
  });

  LocationMigrationService service(
    Future<http.Response> Function(http.Request) handler,
  ) => LocationMigrationService(
    storage: storage,
    api: PlacesApi(client: MockClient(handler), baseUrl: 'https://api.test'),
    clearPrayerCache: (id) async => cleared.add(id),
  );

  http.Response searchResponse(List<Map<String, dynamic>> results) =>
      http.Response(
        jsonEncode({'query': '', 'results': results}),
        200,
        headers: _jsonHeaders,
      );

  test('eslenmis konum atlanir, guvenli eslesme otomatik baglanir', () async {
    await storage.saveLocation(
      const Location(
        id: 'diyanet-9547',
        province: 'İstanbul',
        district: 'Şile',
        cityId: 9547,
      ),
    );
    const silivri = Location(
      id: 'photon-1',
      province: 'İstanbul',
      district: 'Silivri',
      latitude: 41.07,
      longitude: 28.24,
      customName: 'Yazlık',
    );
    await storage.saveLocation(silivri);
    await storage.saveActiveLocation(silivri);

    var calls = 0;
    final report = await service((req) async {
      calls++;
      expect(req.url.path, '/v1/places/search');
      expect(req.url.queryParameters['q'], 'Silivri İstanbul');
      return searchResponse([
        match(9548, 'Silivri', 'İstanbul', lat: 41.0733, lon: 28.2467),
      ]);
    }).run();

    expect(calls, 1, reason: 'eslenmis konum icin istek atilmaz');
    expect(report.items, hasLength(1));
    expect(report.items.single.decision, MigrationDecision.mapped);
    expect(report.mappedCount, 1);
    expect(report.needsUserInput, isFalse);

    final saved = (await storage.getSavedLocations()).firstWhere(
      (l) => l.id == 'photon-1',
    );
    expect(saved.cityId, 9548);
    expect(saved.stateId, 539);
    expect(saved.countryId, 2);
    expect(saved.displayLabel, 'Silivri, İstanbul');
    expect(saved.customName, 'Yazlık');
    expect(saved.type, LocationType.manual);
    expect(
      saved.latitude,
      41.0733,
      reason: 'manuel konumda ilce merkezi koordinati',
    );
    expect((await storage.getActiveLocation())?.cityId, 9548);
    expect(cleared, ['photon-1']);
  });

  test(
    'alias eslesmesi (Kadikoy -> Istanbul merkez) guvenli sayilir',
    () async {
      await storage.saveLocation(
        const Location(id: 'p2', province: 'İstanbul', district: 'Kadıköy'),
      );

      final report = await service(
        (_) async => searchResponse([
          match(9541, 'İstanbul', 'İstanbul', centre: true, alias: 'Kadıköy'),
        ]),
      ).run();

      expect(report.items.single.decision, MigrationDecision.mapped);
      final saved = (await storage.getSavedLocations()).single;
      expect(saved.cityId, 9541);
      expect(saved.displayLabel, 'İstanbul (Merkez)');
    },
  );

  test('belirsiz sonuc: oneriler raporlanir, konum degismez', () async {
    await storage.saveLocation(
      const Location(id: 'p3', province: 'Antalya', district: 'Kemer'),
    );

    // İlk sonuç ili tutmuyor: sunucu sırasına güvenilmez, kullanıcı seçer.
    final report = await service(
      (_) async => searchResponse([
        match(1, 'Kemer', 'Burdur'),
        match(2, 'Kemer', 'Antalya'),
      ]),
    ).run();

    expect(report.items.single.decision, MigrationDecision.ambiguous);
    expect(report.items.single.suggestions, hasLength(2));
    expect(report.items.single.location.id, 'p3');
    expect((await storage.getSavedLocations()).single.cityId, isNull);
    expect(report.needsUserInput, isTrue);
    expect(cleared, isEmpty);
  });

  test('sonuc yok -> desteklenmiyor', () async {
    await storage.saveLocation(
      const Location(id: 'p4', province: 'Berlin', district: 'Mitte'),
    );

    final report = await service((_) async => searchResponse([])).run();

    expect(report.items.single.decision, MigrationDecision.unsupported);
    expect(report.items.single.suggestions, isEmpty);
    expect(report.needsUserInput, isTrue);
  });

  test(
    'GPS konumu koordinattan cozulur; cihaz koordinati ve gps kimligi korunur',
    () async {
      await storage.saveLocation(
        const Location(
          id: 'gps',
          province: 'İstanbul',
          district: 'Şile',
          latitude: 41.2,
          longitude: 29.7,
          type: LocationType.gps,
        ),
      );

      final report = await service((req) async {
        expect(req.url.path, '/v1/places/resolve');
        expect(req.url.queryParameters['lat'], '41.2');
        expect(req.url.queryParameters['lon'], '29.7');
        return http.Response(
          jsonEncode({
            'city': match(9547, 'Şile', 'İstanbul', lat: 41.1758, lon: 29.6127),
            'distanceKm': 3.1,
          }),
          200,
          headers: _jsonHeaders,
        );
      }).run();

      expect(report.items.single.decision, MigrationDecision.mapped);
      final gps = (await storage.getSavedLocations()).single;
      expect(gps.id, 'gps');
      expect(gps.type, LocationType.gps);
      expect(gps.cityId, 9547);
      expect(gps.latitude, 41.2);
      expect(gps.longitude, 29.7);
      expect(cleared, ['gps']);
    },
  );

  test('GPS konumu koordinatsizsa arama ile eslenir', () async {
    await storage.saveLocation(
      const Location(
        id: 'gps',
        province: 'İstanbul',
        district: 'Şile',
        type: LocationType.gps,
      ),
    );

    final report = await service((req) async {
      expect(req.url.path, '/v1/places/search');
      return searchResponse([match(9547, 'Şile', 'İstanbul')]);
    }).run();

    expect(report.items.single.decision, MigrationDecision.mapped);
    final gps = (await storage.getSavedLocations()).single;
    expect(gps.id, 'gps');
    expect(gps.type, LocationType.gps);
    expect(gps.cityId, 9547);
  });

  test('GPS Turkiye disi -> desteklenmiyor', () async {
    await storage.saveLocation(
      const Location(
        id: 'gps',
        province: 'Paris',
        district: 'Paris',
        latitude: 48.85,
        longitude: 2.35,
        type: LocationType.gps,
      ),
    );

    final report = await service(
      (_) async => http.Response(
        '{"error":{"code":"NO_COVERAGE","message":"x"}}',
        404,
        headers: _jsonHeaders,
      ),
    ).run();

    expect(report.items.single.decision, MigrationDecision.unsupported);
    expect((await storage.getSavedLocations()).single.cityId, isNull);
  });

  test('sunucu hatasi run() ile disari cikar, konumlar degismez', () async {
    await storage.saveLocation(
      const Location(id: 'p5', province: 'İstanbul', district: 'Şile'),
    );

    await expectLater(
      service((_) async => http.Response('boom', 500)).run(),
      throwsA(isA<Exception>()),
    );

    expect((await storage.getSavedLocations()).single.cityId, isNull);
    expect(cleared, isEmpty);
  });

  test('sunucu hazir degilse (503) run() disari cikar', () async {
    await storage.saveLocation(
      const Location(id: 'p6', province: 'İstanbul', district: 'Şile'),
    );

    await expectLater(
      service((_) async => http.Response('', 503)).run(),
      throwsA(isA<PlacesNotReadyException>()),
    );
  });

  test('onceki konum eslenmis, sonraki hata: eslenen kalir', () async {
    await storage.saveLocation(
      const Location(id: 'ok', province: 'İstanbul', district: 'Şile'),
    );
    await storage.saveLocation(
      const Location(id: 'bad', province: 'İstanbul', district: 'Silivri'),
    );

    await expectLater(
      service((req) async {
        if (req.url.queryParameters['q']!.startsWith('Şile')) {
          return searchResponse([match(9547, 'Şile', 'İstanbul')]);
        }
        return http.Response('boom', 500);
      }).run(),
      throwsA(isA<Exception>()),
    );

    final saved = await storage.getSavedLocations();
    expect(saved.firstWhere((l) => l.id == 'ok').cityId, 9547);
    expect(saved.firstWhere((l) => l.id == 'bad').cityId, isNull);
    expect(cleared, ['ok']);
  });

  test('isConfident kurallari', () {
    final sile = PlaceMatch.fromJson(match(9547, 'Şile', 'İstanbul'));
    expect(
      LocationMigrationService.isConfident(
        sile,
        const Location(id: 'a', province: 'ISTANBUL', district: 'SILE'),
      ),
      isTrue,
      reason: 'buyuk harf ve Turkce karakter farki katlanir',
    );
    expect(
      LocationMigrationService.isConfident(
        sile,
        const Location(id: 'a', province: 'Ankara', district: 'Şile'),
      ),
      isFalse,
      reason: 'il tutmuyorsa ilce adi yeterli degil',
    );

    final centre = PlaceMatch.fromJson(
      match(9206, 'Ankara', 'Ankara', centre: true),
    );
    expect(
      LocationMigrationService.isConfident(
        centre,
        const Location(id: 'a', province: 'Ankara', district: 'Ankara'),
      ),
      isTrue,
      reason: 'il merkezi: ilce = il',
    );
    expect(
      LocationMigrationService.isConfident(
        centre,
        const Location(id: 'a', province: 'Ankara', district: 'Çankaya'),
      ),
      isFalse,
      reason: 'alias yoksa merkez ilce adi eslesmez',
    );

    final aliased = PlaceMatch.fromJson(
      match(9206, 'Ankara', 'Ankara', centre: true, alias: 'Çankaya'),
    );
    expect(
      LocationMigrationService.isConfident(
        aliased,
        const Location(id: 'a', province: 'Ankara', district: 'Çankaya'),
      ),
      isTrue,
      reason: 'sunucunun bildirdigi alias ilceyle tutuyor',
    );
    expect(
      LocationMigrationService.isConfident(
        aliased,
        const Location(id: 'a', province: 'Ankara', district: 'Keçiören'),
      ),
      isFalse,
      reason: 'alias baska ilceye ait',
    );
  });
}
