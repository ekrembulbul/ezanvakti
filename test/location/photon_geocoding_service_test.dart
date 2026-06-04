import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ezanvakti/features/location/data/photon_geocoding_service.dart';

class FakeHttpClient extends http.BaseClient {
  final String body;
  final int status;
  Uri? lastUrl;
  Map<String, String>? lastHeaders;
  int callCount = 0;

  FakeHttpClient({this.body = '', this.status = 200});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    callCount++;
    lastUrl = request.url;
    lastHeaders = request.headers;
    return http.StreamedResponse(Stream.value(utf8.encode(body)), status);
  }
}

const _validResponse = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "geometry": {"type": "Point", "coordinates": [29.0227, 40.9828]},
      "properties": {
        "osm_id": 123, "osm_type": "R", "name": "Kadıköy",
        "state": "İstanbul", "county": "İstanbul", "country": "Türkiye",
        "countrycode": "tr"
      }
    },
    {
      "geometry": {"type": "Point", "coordinates": [10.75, 59.91]},
      "properties": {
        "osm_id": 456, "osm_type": "N", "name": "Oslo",
        "state": "Oslo", "country": "Norge"
      }
    }
  ]
}
''';

void main() {
  group('PhotonGeocodingService.search', () {
    test('Parses valid GeoJSON into suggestions', () async {
      final client = FakeHttpClient(body: _validResponse);
      final service = PhotonGeocodingService(httpClient: client);

      final results = await service.search('kadık');

      expect(results, hasLength(2));
      final first = results.first;
      expect(first.name, equals('Kadıköy'));
      expect(first.province, equals('İstanbul'));
      expect(first.district, equals('Kadıköy'));
      expect(first.latitude, equals(40.9828));
      expect(first.longitude, equals(29.0227));
      expect(first.id, equals('photon-R123'));
      expect(first.displayLabel, equals('Kadıköy, İstanbul, Türkiye'));
      // Ülke kodu büyük harfe normalize edilir (bölgesel varsayılan için).
      expect(first.countryCode, equals('TR'));
    });

    test('toLocation carries coordinates and label', () async {
      final client = FakeHttpClient(body: _validResponse);
      final service = PhotonGeocodingService(httpClient: client);

      final location = (await service.search('oslo'))[1].toLocation();

      expect(location.province, equals('Oslo'));
      expect(location.district, equals('Oslo'));
      expect(location.latitude, equals(59.91));
      expect(location.longitude, equals(10.75));
    });

    test('Short query returns empty without hitting the network', () async {
      final client = FakeHttpClient(body: _validResponse);
      final service = PhotonGeocodingService(httpClient: client);

      final results = await service.search('a');

      expect(results, isEmpty);
      expect(client.callCount, equals(0));
    });

    test('Sends a descriptive User-Agent, not the blocked Dart default', () async {
      final client = FakeHttpClient(body: _validResponse);
      final service = PhotonGeocodingService(httpClient: client);

      await service.search('kadik');

      // http header anahtarlarini kucuk harfe normalize eder.
      final userAgent = client.lastHeaders!['user-agent'];
      expect(userAgent, isNotNull);
      expect(userAgent, contains('EzanVakti'));
      expect(userAgent, isNot(contains('Dart/')));
    });

    test('Bias coordinates are added to the request URL', () async {
      final client = FakeHttpClient(body: _validResponse);
      final service = PhotonGeocodingService(httpClient: client);

      await service.search('merkez', biasLatitude: 39.92, biasLongitude: 32.85);

      final query = client.lastUrl!.queryParameters;
      expect(query['q'], equals('merkez'));
      expect(query['lat'], equals('39.92'));
      expect(query['lon'], equals('32.85'));
      // Photon public 'tr' lang'i desteklemediginden lang gonderilmez.
      expect(query.containsKey('lang'), isFalse);
    });

    test('Malformed JSON degrades to empty list', () async {
      final client = FakeHttpClient(body: '{not json');
      final service = PhotonGeocodingService(httpClient: client);

      expect(await service.search('test'), isEmpty);
    });

    test('Non-200 response degrades to empty list', () async {
      final client = FakeHttpClient(body: '', status: 503);
      final service = PhotonGeocodingService(httpClient: client);

      expect(await service.search('test'), isEmpty);
    });

    test('Features missing coordinates are skipped', () async {
      final client = FakeHttpClient(
        body: '{"features": [{"properties": {"name": "Boş"}}]}',
      );
      final service = PhotonGeocodingService(httpClient: client);

      expect(await service.search('bos'), isEmpty);
    });
  });
}
