import 'dart:convert';

import 'package:ezanvakti/core/exceptions/api_exception.dart';
import 'package:ezanvakti/core/exceptions/parse_exception.dart';
import 'package:ezanvakti/features/sermons/data/sermons_api.dart';
import 'package:ezanvakti/features/sermons/domain/sermon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'sermon_fixtures.dart';

http.Response ok(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

SermonsApi apiWith(Future<http.Response> Function(http.Request) h) =>
    SermonsApi(client: MockClient(h), baseUrl: 'https://api.test');

void main() {
  test('fetchIndex sözleşmeyi ayrıştırır', () async {
    late Uri seen;
    final api = apiWith((req) async {
      seen = req.url;
      return ok(
        indexJson([
          summaryJson(),
          summaryJson(
            id: '2026-05-27-bayram',
            date: '2026-05-27',
            kind: 'bayram',
            title: 'Kurban Bayramı Hutbesi',
            pdfs: {},
          ),
        ]),
      );
    });
    final list = await api.fetchIndex();
    expect(seen.toString(), 'https://api.test/v1/sermons');
    expect(list, hasLength(2));
    final first = list.first;
    expect(first.id, '2026-09-25-cuma');
    expect(first.date, DateTime(2026, 9, 25));
    expect(first.kind, SermonKind.cuma);
    expect(first.pdfs['en']!.title, 'Our Responsibility to Convey Islam');
    expect(first.pdfs['en']!.url.path, endsWith('.pdf'));
    expect(list.last.kind, SermonKind.bayram);
    expect(list.last.pdfs, isEmpty);
  });

  test('fetchIndex bilinmeyen tür ya da eksik alanı atlamaz, hata verir', () {
    final api = apiWith(
      (_) async => ok(indexJson([summaryJson(kind: 'vaaz')])),
    );
    expect(api.fetchIndex(), throwsA(isA<ParseException>()));
  });

  test('fetchText metni ve dipnotları ayrıştırır', () async {
    late Uri seen;
    final api = apiWith((req) async {
      seen = req.url;
      return ok(textJson());
    });
    final text = await api.fetchText('2026-09-25-cuma');
    expect(seen.toString(), 'https://api.test/v1/sermons/2026-09-25-cuma');
    expect(text.heading, 'TEBLİĞ SORUMLULUĞUMUZ');
    expect(text.paragraphs, hasLength(2));
    expect(text.footnotes.single.n, 1);
    expect(text.signature, 'Din Hizmetleri Genel Müdürlüğü');
  });

  test('sunucu hatası ApiException', () {
    final api = apiWith((_) async => http.Response('x', 503));
    expect(api.fetchIndex(), throwsA(isA<ApiException>()));
    expect(api.fetchText('2026-09-25-cuma'), throwsA(isA<ApiException>()));
  });
}
