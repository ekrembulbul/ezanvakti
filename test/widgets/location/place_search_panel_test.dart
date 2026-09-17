import 'dart:convert';

import 'package:ezanvakti/features/location/data/places_api.dart';
import 'package:ezanvakti/presentation/widgets/location/place_search_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../theme_harness.dart';

const _headers = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _match(
  int id,
  String name,
  String state, {
  bool centre = false,
  String? alias,
}) => {
  'id': id,
  'name': name,
  'stateName': state,
  'displayName': centre ? '$name (Merkez)' : '$name, $state',
  'stateId': 539,
  'countryId': 2,
  'isCentre': centre,
  'latitude': 41.0,
  'longitude': 29.0,
  'matchedAlias': ?alias,
};

http.Response _ok(List<Map<String, dynamic>> results) => http.Response(
  jsonEncode({'query': '', 'results': results}),
  200,
  headers: _headers,
);

void main() {
  late List<String> queries;

  setUp(() => queries = []);

  Widget panel(
    Future<http.Response> Function(http.Request) handler, {
    ValueChanged<PlaceMatch>? onSelected,
  }) => wrapWithTheme(
    PlaceSearchPanel(
      api: PlacesApi(
        client: MockClient((req) {
          queries.add(req.url.queryParameters['q'] ?? '');
          return handler(req);
        }),
        baseUrl: 'https://api.test',
      ),
      onSelected: onSelected ?? (_) {},
    ),
  );

  testWidgets('Acilista bos sorguyla il merkezleri listelenir', (tester) async {
    await tester.pumpWidget(
      panel(
        (_) async => _ok([
          _match(9541, 'İstanbul', 'İstanbul', centre: true),
          _match(9206, 'Ankara', 'Ankara', centre: true),
        ]),
      ),
    );
    await tester.pump();

    expect(queries, ['']);
    expect(find.text('İstanbul (Merkez)'), findsOneWidget);
    expect(find.text('Ankara (Merkez)'), findsOneWidget);
  });

  testWidgets('Yazinca 300 ms sonra tek istek atilir; alias alt satirda', (
    tester,
  ) async {
    await tester.pumpWidget(
      panel((req) async {
        final q = req.url.queryParameters['q'];
        if (q == 'kadik') {
          return _ok([
            _match(
              9541,
              'İstanbul',
              'İstanbul',
              centre: true,
              alias: 'Kadıköy',
            ),
          ]);
        }
        return _ok([]);
      }),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'k');
    await tester.pump(const Duration(milliseconds: 350));
    expect(queries, [''], reason: '2 karakterden kisa sorgu istek atmaz');

    await tester.enterText(find.byType(TextField), 'kadi');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'kadik');
    await tester.pump(const Duration(milliseconds: 350));

    expect(queries, ['', 'kadik'], reason: 'debounce ara sorguyu yutar');
    expect(find.text('İstanbul (Merkez)'), findsOneWidget);
    expect(find.text('Kadıköy buna dahil'), findsOneWidget);
  });

  testWidgets('Kutu temizlenince il merkezleri hemen geri gelir', (
    tester,
  ) async {
    await tester.pumpWidget(
      panel((req) async {
        final q = req.url.queryParameters['q'];
        if (q == '') {
          return _ok([_match(9206, 'Ankara', 'Ankara', centre: true)]);
        }
        return _ok([_match(9547, 'Şile', 'İstanbul')]);
      }),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'sile');
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Şile, İstanbul'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    expect(queries, ['', 'sile', '']);
    expect(find.text('Ankara (Merkez)'), findsOneWidget);
  });

  testWidgets('Satira dokunmak secimi bildirir', (tester) async {
    PlaceMatch? selected;
    await tester.pumpWidget(
      panel(
        (_) async => _ok([_match(9547, 'Şile', 'İstanbul')]),
        onSelected: (m) => selected = m,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Şile, İstanbul'));
    expect(selected?.id, 9547);
  });

  testWidgets(
    'Sunucu hatasinda internet uyarisi; yeniden dene sonucsuz sorguda mesaj verir',
    (tester) async {
      var fail = true;
      await tester.pumpWidget(
        panel((_) async => fail ? http.Response('', 503) : _ok([])),
      );
      await tester.pump();

      expect(find.text('Konum eklemek için internet gerekli.'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Yeniden Dene'));
      await tester.pump();

      expect(find.textContaining('Sonuç bulunamadı'), findsOneWidget);
      expect(queries, ['', '']);
    },
  );
}
