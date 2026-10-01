import 'dart:convert';
import 'dart:io';

import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/features/sermons/data/sermons_api.dart';
import 'package:ezanvakti/features/sermons/domain/sermon.dart';
import 'package:ezanvakti/features/sermons/domain/sermon_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'sermon_fixtures.dart';
import 'sermons_api_test.dart' show ok;

class _SettingsStorage implements LocalStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> getSetting(String key) async => values[key];

  @override
  Future<void> setSetting(String key, String value) async =>
      values[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_SettingsStorage.${invocation.memberName}');
}

void main() {
  late _SettingsStorage storage;
  late List<String> paths;
  late Future<http.Response> Function(http.Request) handler;
  var now = DateTime(2026, 10, 1, 12);

  SermonRepository repo() => SermonRepository(
    api: SermonsApi(
      client: MockClient((req) {
        paths.add(req.url.path);
        return handler(req);
      }),
      baseUrl: 'https://api.test',
    ),
    storage: storage,
    now: () => now,
  );

  setUp(() {
    storage = _SettingsStorage();
    paths = [];
    now = DateTime(2026, 10, 1, 12);
    handler = (req) async => req.url.path == '/v1/sermons'
        ? ok(indexJson([summaryJson()]))
        : ok(textJson());
  });

  group('index', () {
    test('ilk çağrıda indirir ve saklar', () async {
      final list = await repo().index();
      expect(list.single.id, '2026-09-25-cuma');
      expect(paths, ['/v1/sermons']);
      expect(storage.values['sermons_index'], isNotNull);
    });

    test('saklanan bir saatten yeniyse istek atmaz', () async {
      await repo().index();
      now = now.add(const Duration(minutes: 59));
      await repo().index();
      expect(paths, ['/v1/sermons']);
    });

    test('bir saat geçtiyse yeniden ister; force her zaman ister', () async {
      await repo().index();
      now = now.add(const Duration(minutes: 61));
      await repo().index();
      await repo().index(force: true);
      expect(paths, ['/v1/sermons', '/v1/sermons', '/v1/sermons']);
    });

    test('ağ hatasında saklananı döner', () async {
      await repo().index();
      now = now.add(const Duration(hours: 2));
      handler = (_) async => throw const SocketException('offline');
      expect((await repo().index()).single.id, '2026-09-25-cuma');
    });

    test('ağ hatası ve saklanan yoksa hata fırlar', () {
      handler = (_) async => throw const SocketException('offline');
      expect(repo().index(), throwsA(isA<SocketException>()));
    });

    test('listeden düşen hutbenin metni silinir', () async {
      final r = repo();
      await r.index();
      await r.text('2026-09-25-cuma');
      handler = (req) async => ok(
        indexJson([summaryJson(id: '2026-10-02-cuma', date: '2026-10-02')]),
      );
      await r.index(force: true);
      final texts =
          jsonDecode(storage.values['sermon_texts']!) as Map<String, dynamic>;
      expect(texts.keys, isNot(contains('2026-09-25-cuma')));
    });
  });

  group('text', () {
    test('ilk açılışta indirir, sonra saklanandan okur', () async {
      final r = repo();
      final t1 = await r.text('2026-09-25-cuma');
      final t2 = await r.text('2026-09-25-cuma');
      expect(t1.heading, 'TEBLİĞ SORUMLULUĞUMUZ');
      expect(t2.paragraphs, t1.paragraphs);
      expect(paths, ['/v1/sermons/2026-09-25-cuma']);
    });

    test('ağ yok ve saklı değilse hata', () {
      handler = (_) async => throw const SocketException('offline');
      expect(repo().text('2026-09-25-cuma'), throwsA(isA<SocketException>()));
    });
  });

  group('yazı boyutu', () {
    test('varsayılan 2, sınırlar 0–4', () async {
      final r = repo();
      expect(await r.fontStep(), 2);
      await r.setFontStep(9);
      expect(await r.fontStep(), 4);
      await r.setFontStep(-1);
      expect(await r.fontStep(), 0);
    });
  });

  group('featured', () {
    SermonSummary s(String date, String kind) => SermonSummary.fromJson(
      summaryJson(id: '$date-$kind', date: date, kind: kind),
    );

    test('cuma hutbesi perşembe ve cuma günü öne çıkar', () {
      final list = [s('2026-10-02', 'cuma'), s('2026-09-25', 'cuma')];
      expect(
        SermonRepository.featured(list, DateTime(2026, 10, 1, 9)),
        same(list.first),
      ); // perşembe
      expect(
        SermonRepository.featured(list, DateTime(2026, 10, 2, 23)),
        same(list.first),
      ); // cuma
      expect(
        SermonRepository.featured(list, DateTime(2026, 10, 3, 0, 1)),
        isNull,
      ); // cumartesi
      expect(
        SermonRepository.featured(list, DateTime(2026, 9, 30, 23)),
        isNull,
      ); // çarşamba
    });

    test('bayram hutbesi bayram günü ve bir gün öncesi', () {
      final list = [s('2027-03-10', 'bayram')];
      expect(
        SermonRepository.featured(list, DateTime(2027, 3, 9, 20)),
        same(list.first),
      );
      expect(SermonRepository.featured(list, DateTime(2027, 3, 8, 20)), isNull);
    });

    test('boş liste null', () {
      expect(SermonRepository.featured(const [], now), isNull);
    });
  });
}
