import 'dart:convert';
import 'dart:io';

import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/features/daily_content/data/daily_content_api.dart';
import 'package:ezanvakti/features/daily_content/domain/daily_content.dart';
import 'package:ezanvakti/features/daily_content/domain/daily_content_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'daily_content_api_test.dart' show contentJson, jsonResponse;

class _SettingsStorage implements LocalStorage {
  final Map<String, String> values = {};
  Object? failWith;

  @override
  Future<String?> getSetting(String key) async {
    if (failWith case final e?) throw e;
    return values[key];
  }

  @override
  Future<void> setSetting(String key, String value) async {
    if (failWith case final e?) throw e;
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_SettingsStorage.${invocation.memberName}');
}

Map<String, Object?> contentOn(String date) => {...contentJson, 'date': date};

void main() {
  late _SettingsStorage storage;
  late int calls;
  late Future<http.Response> Function(http.Request) handler;
  var now = DateTime(2026, 10, 2, 9, 0);

  DailyContentRepository repo() => DailyContentRepository(
    api: DailyContentApi(
      client: MockClient((req) {
        calls++;
        return handler(req);
      }),
      baseUrl: 'https://api.test',
    ),
    storage: storage,
    now: () => now,
  );

  void store(String date) => storage.values['daily_content'] = jsonEncode(
    DailyContent.fromJson(contentOn(date)).toJson(),
  );

  setUp(() {
    storage = _SettingsStorage();
    calls = 0;
    now = DateTime(2026, 10, 2, 9, 0);
    handler = (_) async => jsonResponse(contentOn('2026-10-02'));
  });

  test('bugünkü içerik saklıysa istek atmaz', () async {
    store('2026-10-02');
    final c = await repo().load();
    expect(c!.date, '2026-10-02');
    expect(calls, 0);
  });

  test('son deneme 30 dakikadan yeniyse istek atmaz, dünkünü döner', () async {
    store('2026-10-01');
    storage.values['daily_content_attempt'] = DateTime(
      2026,
      10,
      2,
      8,
      50,
    ).toIso8601String();
    final c = await repo().load();
    expect(c!.date, '2026-10-01');
    expect(calls, 0);
  });

  test('son deneme 30 dakikadan eskiyse yeni içeriği alır ve saklar', () async {
    store('2026-10-01');
    storage.values['daily_content_attempt'] = DateTime(
      2026,
      10,
      2,
      8,
      29,
    ).toIso8601String();
    final c = await repo().load();
    expect(c!.date, '2026-10-02');
    expect(calls, 1);
    expect(jsonDecode(storage.values['daily_content']!)['date'], '2026-10-02');
  });

  test('sunucuda henüz yoksa saklananı döner ve denemeyi yazar', () async {
    store('2026-10-01');
    handler = (_) async => jsonResponse({
      'error': {'code': 'NOT_FOUND'},
    }, 404);
    final c = await repo().load();
    expect(c!.date, '2026-10-01');
    expect(storage.values['daily_content_attempt'], now.toIso8601String());
  });

  test('ağ hatasında fırlatmaz, saklananı döner', () async {
    store('2026-10-01');
    handler = (_) async => throw const SocketException('offline');
    final c = await repo().load();
    expect(c!.date, '2026-10-01');
  });

  test('hiç içerik yoksa ve sunucu hata verirse null döner', () async {
    handler = (_) async => http.Response('x', 500);
    expect(await repo().load(), isNull);
  });

  test('bozuk saklı JSON yok sayılır', () async {
    storage.values['daily_content'] = '{bozuk';
    final c = await repo().load();
    expect(c!.date, '2026-10-02');
  });

  test('depo hatasında fırlatmaz, null döner', () async {
    storage.failWith = StateError('sqlite');
    expect(await repo().load(), isNull);
  });

  test('visible: 7 günlük görünür, 8 günlük görünmez', () {
    final weekOld = DailyContent.fromJson(contentOn('2026-09-25'));
    final older = DailyContent.fromJson(contentOn('2026-09-24'));
    expect(DailyContentRepository.visible(weekOld, now), same(weekOld));
    expect(DailyContentRepository.visible(older, now), isNull);
    expect(DailyContentRepository.visible(null, now), isNull);
  });
}
