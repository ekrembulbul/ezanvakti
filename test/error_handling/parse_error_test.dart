import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ezanvakti/features/prayer_times/data/awqat_salah_provider.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/exceptions/parse_exception.dart';

class MockHttpClient extends http.BaseClient {
  final String? responseBody;
  final int statusCode;

  MockHttpClient({this.responseBody, this.statusCode = 200});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value((responseBody ?? '').codeUnits),
      statusCode,
    );
  }
}

void main() {
  group('Parse Error Handling - API Provider', () {
    final testLocation = const Location(
      id: '9635',
      province: 'İstanbul',
      district: 'Kadıköy',
      latitude: 40.9828,
      longitude: 29.0227,
    );
    final testDate = DateTime(2024, 6, 15);

    test('Throws ParseException on invalid JSON format', () async {
      final mockClient = MockHttpClient(responseBody: '{invalid json}');
      final provider = AwqatSalahProvider(httpClient: mockClient);

      expect(
        () => provider.fetchDailyPrayerTime(
          location: testLocation,
          date: testDate,
        ),
        throwsA(isA<ParseException>()),
      );
    });

    test('Throws ParseException on missing data field', () async {
      final mockClient = MockHttpClient(
        responseBody: '{"code": 200, "status": "OK"}',
      );
      final provider = AwqatSalahProvider(httpClient: mockClient);

      expect(
        () => provider.fetchDailyPrayerTime(
          location: testLocation,
          date: testDate,
        ),
        throwsA(isA<ParseException>()),
      );
    });

    test('Throws ParseException on missing timings field', () async {
      final mockClient = MockHttpClient(
        responseBody: '{"code": 200, "status": "OK", "data": {}}',
      );
      final provider = AwqatSalahProvider(httpClient: mockClient);

      expect(
        () => provider.fetchDailyPrayerTime(
          location: testLocation,
          date: testDate,
        ),
        throwsA(isA<ParseException>()),
      );
    });

    test('Throws ParseException on invalid time format', () async {
      final mockClient = MockHttpClient(
        responseBody: '''
        {
          "code": 200,
          "status": "OK",
          "data": {
            "timings": {
              "Fajr": "invalid_time",
              "Sunrise": "07:00",
              "Dhuhr": "13:15",
              "Asr": "16:30",
              "Maghrib": "19:00",
              "Isha": "20:30"
            }
          }
        }
        ''',
      );
      final provider = AwqatSalahProvider(httpClient: mockClient);

      expect(
        () => provider.fetchDailyPrayerTime(
          location: testLocation,
          date: testDate,
        ),
        throwsA(isA<ParseException>()),
      );
    });

    test('Throws ParseException on time with missing colon', () async {
      final mockClient = MockHttpClient(
        responseBody: '''
        {
          "code": 200,
          "status": "OK",
          "data": {
            "timings": {
              "Fajr": "0530",
              "Sunrise": "07:00",
              "Dhuhr": "13:15",
              "Asr": "16:30",
              "Maghrib": "19:00",
              "Isha": "20:30"
            }
          }
        }
        ''',
      );
      final provider = AwqatSalahProvider(httpClient: mockClient);

      expect(
        () => provider.fetchDailyPrayerTime(
          location: testLocation,
          date: testDate,
        ),
        throwsA(isA<ParseException>()),
      );
    });

    test('ParseException contains user-friendly message', () async {
      final mockClient = MockHttpClient(responseBody: '{invalid}');
      final provider = AwqatSalahProvider(httpClient: mockClient);

      try {
        await provider.fetchDailyPrayerTime(
          location: testLocation,
          date: testDate,
        );
        fail('Should have thrown ParseException');
      } on ParseException catch (e) {
        expect(e.getUserMessage(), contains('Veri formatı değişmiş olabilir'));
        expect(e.getUserMessage(), contains('güncellemeyi deneyin'));
      }
    });

    test('ParseException contains context information', () async {
      final mockClient = MockHttpClient(responseBody: '{}');
      final provider = AwqatSalahProvider(httpClient: mockClient);

      try {
        await provider.fetchDailyPrayerTime(
          location: testLocation,
          date: testDate,
        );
        fail('Should have thrown ParseException');
      } on ParseException catch (e) {
        expect(e.context, isNotNull);
        expect(e.context, contains('AwqatSalahProvider'));
      }
    });

    test('Returns null on network errors (not parse errors)', () async {
      final mockClient = MockHttpClient(
        statusCode: 500,
        responseBody: 'Server error',
      );
      final provider = AwqatSalahProvider(httpClient: mockClient);

      final result = await provider.fetchDailyPrayerTime(
        location: testLocation,
        date: testDate,
      );

      expect(result, isNull);
    });

    test('Valid JSON response does not throw', () async {
      final mockClient = MockHttpClient(
        responseBody: '''
        {
          "code": 200,
          "status": "OK",
          "data": {
            "timings": {
              "Fajr": "05:30",
              "Sunrise": "07:00",
              "Dhuhr": "13:15",
              "Asr": "16:30",
              "Maghrib": "19:00",
              "Isha": "20:30"
            }
          }
        }
        ''',
      );
      final provider = AwqatSalahProvider(httpClient: mockClient);

      final result = await provider.fetchDailyPrayerTime(
        location: testLocation,
        date: testDate,
      );

      expect(result, isNotNull);
      expect(result!.fajr.hour, equals(5));
      expect(result.fajr.minute, equals(30));
    });
  });

  group('Parse Error Handling - Storage', () {
    test('ParseException contains original error', () {
      final exception = ParseException(
        message: 'Test parse error',
        originalError: FormatException('Invalid format'),
        context: 'Test context',
      );

      expect(exception.message, equals('Test parse error'));
      expect(exception.originalError, isA<FormatException>());
      expect(exception.context, equals('Test context'));
    });

    test('ParseException toString includes all information', () {
      final exception = ParseException(
        message: 'Test error',
        originalError: 'Original',
        context: 'TestContext',
      );

      final stringValue = exception.toString();
      expect(stringValue, contains('Test error'));
      expect(stringValue, contains('TestContext'));
      expect(stringValue, contains('Original'));
    });

    test('getUserMessage returns Turkish user-friendly message', () {
      final exception = ParseException(message: 'Any technical message');

      final userMessage = exception.getUserMessage();
      expect(userMessage, isA<String>());
      expect(userMessage.length, greaterThan(0));
      expect(userMessage, contains('Veri formatı'));
    });
  });

  group('Parse Error Handling - Integration', () {
    test('API parse error is caught and logged', () async {
      final mockClient = MockHttpClient(responseBody: 'not json');
      final provider = AwqatSalahProvider(httpClient: mockClient);
      final testLocation = const Location(
        id: '9635',
        province: 'İstanbul',
        district: 'Kadıköy',
        latitude: 40.9828,
        longitude: 29.0227,
      );

      expect(
        () => provider.fetchDailyPrayerTime(
          location: testLocation,
          date: DateTime.now(),
        ),
        throwsA(isA<ParseException>()),
      );
    });

    test('Multiple parse errors in batch do not crash app', () async {
      final mockClient = MockHttpClient(
        responseBody: '{"data": {"timings": {"Fajr": "invalid"}}}',
      );
      final provider = AwqatSalahProvider(httpClient: mockClient);
      final testLocation = const Location(
        id: '9635',
        province: 'İstanbul',
        district: 'Kadıköy',
        latitude: 40.9828,
        longitude: 29.0227,
      );

      final results = await provider.fetchPrayerTimes(
        location: testLocation,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 3),
      );

      expect(results, isEmpty);
    });
  });
}
