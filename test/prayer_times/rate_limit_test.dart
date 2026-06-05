import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ezanvakti/features/prayer_times/data/awqat_salah_provider.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/exceptions/api_exception.dart';

/// Uç (calendar/timings) bazında istek sayan ve sabit bir durum kodu dönen
/// mock client. Rate-limit (429) davranışını doğrulamak için kullanılır.
class CountingHttpClient extends http.BaseClient {
  int calendarCount = 0;
  int timingsCount = 0;
  final int statusCode;

  CountingHttpClient(this.statusCode);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.contains('/calendar')) calendarCount++;
    if (request.url.path.contains('/timings')) timingsCount++;
    return http.StreamedResponse(
      Stream.value(utf8.encode('{}')),
      statusCode,
    );
  }
}

void main() {
  const location = Location(
    id: '1',
    province: 'İstanbul',
    district: 'Fatih',
    latitude: 41.0,
    longitude: 29.0,
  );

  group('AwqatSalahProvider rate-limit (429) handling', () {
    test(
      'Calendar 429 does not fall back to per-day endpoint (no amplification)',
      () async {
        final client = CountingHttpClient(429);
        final provider = AwqatSalahProvider(httpClient: client);

        await expectLater(
          provider.fetchPrayerTimes(
            location: location,
            startDate: DateTime(2024, 6, 1),
            endDate: DateTime(2024, 6, 10),
          ),
          throwsA(isA<ApiException>()),
        );

        // Takvim ucu yeniden denendi ama tek tek günlük istek ATILMADI.
        expect(client.calendarCount, equals(3));
        expect(client.timingsCount, equals(0));
      },
    );

    test('Daily 429 returns null after bounded retries', () async {
      final client = CountingHttpClient(429);
      final provider = AwqatSalahProvider(httpClient: client);

      final result = await provider.fetchDailyPrayerTime(
        location: location,
        date: DateTime(2024, 6, 15),
      );

      // Geçici hata: çağıran önbelleğe düşebilsin diye null döner.
      expect(result, isNull);
      // Sınırlı sayıda yeniden deneme (sonsuz döngü yok).
      expect(client.timingsCount, equals(3));
    });
  });
}
