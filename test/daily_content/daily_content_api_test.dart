import 'dart:convert';

import 'package:ezanvakti/core/exceptions/api_exception.dart';
import 'package:ezanvakti/core/exceptions/parse_exception.dart';
import 'package:ezanvakti/features/daily_content/data/daily_content_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const contentJson = {
  'date': '2026-10-01',
  'dayOfYear': 274,
  'verse': '"Kötü işler yapmak için tuzak kuranlar…"',
  'verseSource': '(Nahl, 16/45)',
  'hadith': '“Âdemoğlu ihtiyarlayıp çöker…”',
  'hadithSource': '(Müslim, “Zekât”, 115)',
  'prayer': '"Ey yerleri ve gökleri yaratan…"',
  'prayerSource': '(İbn Ebî Şeybe, "Dua", 23)',
};

DailyContentApi apiWith(Future<http.Response> Function(http.Request) h) =>
    DailyContentApi(client: MockClient(h), baseUrl: 'https://api.test');

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('fetch: günün tarihiyle ister ve içeriği ayrıştırır', () async {
    late Uri seen;
    final api = apiWith((req) async {
      seen = req.url;
      return jsonResponse(contentJson);
    });
    final content = await api.fetch(DateTime(2026, 10, 1, 15, 30));
    expect(seen.toString(), 'https://api.test/v1/daily-content/2026-10-01');
    expect(content!.date, '2026-10-01');
    expect(content.verseSource, '(Nahl, 16/45)');
    expect(content.hadith, startsWith('“Âdemoğlu'));
    expect(content.prayerSource, '(İbn Ebî Şeybe, "Dua", 23)');
    expect(content.day, DateTime(2026, 10, 1));
  });

  test('fetch: dua kaynağı yoksa null kalır', () async {
    final api = apiWith(
      (_) async => jsonResponse({...contentJson, 'prayerSource': null}),
    );
    expect((await api.fetch(DateTime(2026, 10, 1)))!.prayerSource, isNull);
  });

  test('fetch: boş ayet/hadis kaynağı içeriği düşürmez', () async {
    final api = apiWith(
      (_) async => jsonResponse({
        ...contentJson,
        'verseSource': '',
        'hadithSource': null,
      }),
    );
    final content = await api.fetch(DateTime(2026, 10, 1));
    expect(content!.verse, contentJson['verse']);
    expect(content.verseSource, isNull);
    expect(content.hadithSource, isNull);
  });

  test('fetch: 404 henüz yok demektir', () async {
    final api = apiWith(
      (_) async => jsonResponse({
        'error': {'code': 'NOT_FOUND'},
      }, 404),
    );
    expect(await api.fetch(DateTime(2026, 10, 1)), isNull);
  });

  test('fetch: 500 ApiException', () async {
    final api = apiWith((_) async => http.Response('x', 500));
    expect(
      () => api.fetch(DateTime(2026, 10, 1)),
      throwsA(isA<ApiException>()),
    );
  });

  test('fetch: bozuk JSON ve eksik alan ParseException', () async {
    final broken = apiWith((_) async => http.Response('{nope', 200));
    expect(
      () => broken.fetch(DateTime(2026, 10, 1)),
      throwsA(isA<ParseException>()),
    );
    final missing = apiWith(
      (_) async => jsonResponse({...contentJson}..remove('hadith')),
    );
    expect(
      () => missing.fetch(DateTime(2026, 10, 1)),
      throwsA(isA<ParseException>()),
    );
  });
}
