import 'dart:convert';

import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/features/sermons/data/sermons_api.dart';
import 'package:ezanvakti/features/sermons/domain/sermon.dart';
import 'package:ezanvakti/features/sermons/domain/sermon_repository.dart';
import 'package:ezanvakti/presentation/screens/sermon_list_screen.dart';
import 'package:ezanvakti/presentation/screens/sermon_reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../sermons/sermon_fixtures.dart';
import '../theme_harness.dart';

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

http.Response _ok(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  late _SettingsStorage storage;
  late Future<http.Response> Function(http.Request) handler;
  late List<Uri> opened;

  setUpAll(() async {
    await initializeDateFormatting('tr', null);
    await initializeDateFormatting('en', null);
  });

  SermonRepository repo() => SermonRepository(
    api: SermonsApi(
      client: MockClient((req) => handler(req)),
      baseUrl: 'https://api.test',
    ),
    storage: storage,
  );

  Future<bool> openUrl(Uri uri) async {
    opened.add(uri);
    return true;
  }

  setUp(() {
    storage = _SettingsStorage();
    opened = [];
    handler = (req) async => req.url.path == '/v1/sermons'
        ? _ok(
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
          )
        : _ok(textJson());
  });

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Locale locale = const Locale('tr'),
  }) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrapWithTheme(screen, locale: locale));
    await tester.pumpAndSettle();
  }

  group('Liste', () {
    testWidgets('Türkçe başlık, tarih ve tür; dokununca okuma ekranı', (
      tester,
    ) async {
      await pump(
        tester,
        SermonListScreen(repository: repo(), openUrl: openUrl),
      );
      expect(find.text('Tebliğ Sorumluluğumuz'), findsOneWidget);
      expect(find.text('25 Eylül 2026 · Cuma'), findsOneWidget);
      expect(find.text('27 Mayıs 2026 · Bayram'), findsOneWidget);
      await tester.tap(find.text('Tebliğ Sorumluluğumuz'));
      await tester.pumpAndSettle();
      expect(find.byType(SermonReaderScreen), findsOneWidget);
    });

    testWidgets('İngilizcede yalnız PDF\'i olanlar, PDF açılır', (
      tester,
    ) async {
      await pump(
        tester,
        SermonListScreen(repository: repo(), openUrl: openUrl),
        locale: const Locale('en'),
      );
      expect(find.text('Our Responsibility to Convey Islam'), findsOneWidget);
      expect(find.text('Kurban Bayramı Hutbesi'), findsNothing);
      await tester.tap(find.text('Our Responsibility to Convey Islam'));
      await tester.pumpAndSettle();
      expect(opened.single.path, endsWith('.pdf'));
    });

    testWidgets('liste alınamazsa hata ve yeniden dene', (tester) async {
      handler = (_) async => http.Response('x', 500);
      await pump(
        tester,
        SermonListScreen(repository: repo(), openUrl: openUrl),
      );
      expect(find.text('Yeniden Dene'), findsOneWidget);
    });
  });

  group('Okuma', () {
    SermonSummary summary() => SermonSummary.fromJson(summaryJson());

    testWidgets('başlık, paragraflar, dipnot, imza ve kaynak', (tester) async {
      await pump(
        tester,
        SermonReaderScreen(
          repository: repo(),
          summary: summary(),
          openUrl: openUrl,
        ),
      );
      expect(find.text('TEBLİĞ SORUMLULUĞUMUZ'), findsOneWidget);
      expect(find.text('Muhterem Müslümanlar!'), findsOneWidget);
      expect(find.text('Dipnotlar'), findsOneWidget);
      expect(find.text('1. İbn Sa’d, Tabakât, I, 219, 220.'), findsOneWidget);
      expect(find.text('Din Hizmetleri Genel Müdürlüğü'), findsOneWidget);
      await tester.tap(find.text('Kaynak: Diyanet Haber'));
      await tester.pumpAndSettle();
      expect(opened.single.host, 'www.diyanethaber.com.tr');
    });

    testWidgets('yazıyı büyüt 17→20 yapar ve kademeyi saklar', (tester) async {
      await pump(
        tester,
        SermonReaderScreen(
          repository: repo(),
          summary: summary(),
          openUrl: openUrl,
        ),
      );
      double size() => tester
          .widget<Text>(find.text('Muhterem Müslümanlar!'))
          .style!
          .fontSize!;
      expect(size(), 17);
      await tester.tap(find.byTooltip('Yazıyı büyüt'));
      await tester.pumpAndSettle();
      expect(size(), 20);
      expect(storage.values['sermon_font_step'], '3');
    });

    testWidgets('en küçükte küçült düğmesi pasif', (tester) async {
      storage.values['sermon_font_step'] = '0';
      await pump(
        tester,
        SermonReaderScreen(
          repository: repo(),
          summary: summary(),
          openUrl: openUrl,
        ),
      );
      await tester.tap(find.byTooltip('Yazıyı küçült'));
      await tester.pumpAndSettle();
      expect(storage.values['sermon_font_step'], '0');
    });
  });
}
