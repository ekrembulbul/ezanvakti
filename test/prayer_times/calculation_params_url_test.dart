import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ezanvakti/features/prayer_times/data/awqat_salah_provider.dart';
import 'package:ezanvakti/core/models/location.dart';

/// İstenen URL'i yakalayıp geçerli bir yanıt döndüren mock client.
class CapturingHttpClient extends http.BaseClient {
  Uri? lastUrl;
  final String body;

  CapturingHttpClient(this.body);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUrl = request.url;
    return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
  }
}

void main() {
  const validBody =
      '{"data":{"timings":{"Fajr":"05:30","Sunrise":"07:00",'
      '"Dhuhr":"13:15","Asr":"16:30","Maghrib":"19:00","Isha":"20:30"}}}';
  final date = DateTime(2024, 6, 15);

  group('AwqatSalahProvider passes per-location calculation params', () {
    test('Default location sends Diyanet method and standard Asr school', () async {
      final client = CapturingHttpClient(validBody);
      final provider = AwqatSalahProvider(httpClient: client);

      await provider.fetchDailyPrayerTime(
        location: const Location(
          id: '1',
          province: 'İstanbul',
          district: 'Fatih',
          latitude: 41.0,
          longitude: 29.0,
        ),
        date: date,
      );

      final query = client.lastUrl!.queryParameters;
      expect(query['method'], equals('13'));
      // Diyanet İkindi'yi asr-ı evvel (standart/Şafi = 0) ile hesaplar.
      expect(query['school'], equals('0'));
      expect(query.containsKey('latitudeAdjustmentMethod'), isFalse);
    });

    test('Custom params are reflected in the request URL', () async {
      final client = CapturingHttpClient(validBody);
      final provider = AwqatSalahProvider(httpClient: client);

      await provider.fetchDailyPrayerTime(
        location: const Location(
          id: '2',
          province: 'Oslo',
          district: 'Sentrum',
          latitude: 59.91,
          longitude: 10.75,
          method: 3,
          school: 0,
          latitudeAdjustmentMethod: 3,
        ),
        date: date,
      );

      final query = client.lastUrl!.queryParameters;
      expect(query['method'], equals('3'));
      expect(query['school'], equals('0'));
      expect(query['latitudeAdjustmentMethod'], equals('3'));
    });
  });
}
