import 'dart:convert';

import 'package:ezanvakti/core/exceptions/api_exception.dart';
import 'package:ezanvakti/core/exceptions/parse_exception.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/features/location/data/places_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const sileJson = {
  'id': 9547,
  'name': 'Şile',
  'stateName': 'İstanbul',
  'displayName': 'Şile, İstanbul',
  'stateId': 539,
  'countryId': 2,
  'isCentre': false,
  'latitude': 41.1758,
  'longitude': 29.6127,
  'qiblaAngle': 151.0,
  'qiblaAngleMagnetic': 146.0,
  'distanceToKaaba': 2400.0,
};

PlacesApi apiWith(Future<http.Response> Function(http.Request) handler) =>
    PlacesApi(client: MockClient(handler), baseUrl: 'https://api.test');

void main() {
  test('search: sorguyu kodlar, sonuclari PlaceMatch yapar', () async {
    late http.Request seen;
    final api = apiWith((req) async {
      seen = req;
      return http.Response(
        jsonEncode({
          'query': 'şile',
          'results': [
            sileJson,
            {
              ...sileJson,
              'id': 9541,
              'name': 'İstanbul',
              'displayName': 'İstanbul (Merkez)',
              'isCentre': true,
              'matchedAlias': 'Kadıköy',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final results = await api.search('şile', limit: 5);
    expect(
      seen.url.toString(),
      'https://api.test/v1/places/search?q=%C5%9File&limit=5',
    );
    expect(results, hasLength(2));
    expect(results.first.id, 9547);
    expect(results.first.displayName, 'Şile, İstanbul');
    expect(results.last.matchedAlias, 'Kadıköy');
    expect(results.last.isCentre, isTrue);
  });

  test(
    'search: 503 NOT_READY ozel hata, 500 ApiException, bozuk govde ParseException',
    () async {
      final notReady = apiWith(
        (_) async =>
            http.Response('{"error":{"code":"NOT_READY","message":"x"}}', 503),
      );
      expect(
        () => notReady.search('a'),
        throwsA(isA<PlacesNotReadyException>()),
      );
      final server = apiWith((_) async => http.Response('boom', 500));
      expect(() => server.search('a'), throwsA(isA<ApiException>()));
      final broken = apiWith((_) async => http.Response('not json', 200));
      expect(() => broken.search('a'), throwsA(isA<ParseException>()));
    },
  );

  test('resolve: en yakin ilce ve mesafe', () async {
    late http.Request seen;
    final api = apiWith((req) async {
      seen = req;
      return http.Response(
        jsonEncode({'city': sileJson, 'distanceKm': 1.2}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final r = await api.resolve(latitude: 41.17, longitude: 29.6);
    expect(seen.url.queryParameters, {'lat': '41.17', 'lon': '29.6'});
    expect(r.city.id, 9547);
    expect(r.distanceKm, 1.2);
  });

  test('resolve: 404 NO_COVERAGE ozel hata', () async {
    final api = apiWith(
      (_) async =>
          http.Response('{"error":{"code":"NO_COVERAGE","message":"x"}}', 404),
    );
    expect(
      () => api.resolve(latitude: 48.85, longitude: 2.35),
      throwsA(isA<NoCoverageException>()),
    );
  });

  test('toLocation: manuel ilce merkezi koordinati, GPS cihaz koordinati', () {
    final match = PlaceMatch.fromJson(sileJson);
    final manual = match.toLocation(type: LocationType.manual);
    expect(manual.id, 'diyanet-9547');
    expect(manual.cityId, 9547);
    expect(manual.stateId, 539);
    expect(manual.countryId, 2);
    expect(manual.province, 'İstanbul');
    expect(manual.district, 'Şile');
    expect(manual.displayLabel, 'Şile, İstanbul');
    expect(manual.latitude, 41.1758);
    final gps = match.toLocation(
      type: LocationType.gps,
      id: 'gps',
      latitude: 41.2,
      longitude: 29.7,
    );
    expect(gps.id, 'gps');
    expect(gps.type, LocationType.gps);
    expect(gps.latitude, 41.2);
    expect(gps.cityId, 9547);
  });
}
