import 'dart:convert';

import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/features/location/data/places_api.dart';
import 'package:ezanvakti/features/location/domain/location_migration_service.dart';
import 'package:ezanvakti/features/location/domain/location_repository.dart';
import 'package:ezanvakti/presentation/screens/location_migration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/fakes.dart';
import '../theme_harness.dart';

const _headers = {'content-type': 'application/json; charset=utf-8'};

const _oldKemer = Location(
  id: 'photon-3',
  province: 'Antalya',
  district: 'Kemer',
  customName: 'Tatil',
  latitude: 36.6,
  longitude: 30.5,
);
const _oldParis = Location(
  id: 'photon-4',
  province: 'Paris',
  district: 'Paris',
);

Map<String, dynamic> _json(int id, String name, String state) => {
  'id': id,
  'name': name,
  'stateName': state,
  'displayName': '$name, $state',
  'stateId': 7,
  'countryId': 2,
  'isCentre': false,
  'latitude': 36.60,
  'longitude': 30.56,
};

PlaceMatch _match(int id, String name, String state) =>
    PlaceMatch.fromJson(_json(id, name, state));

void main() {
  late FakeStorage storage;
  late List<String> cleared;
  late int finished;

  setUp(() async {
    storage = FakeStorage();
    cleared = [];
    finished = 0;
    await storage.saveLocation(_oldKemer);
    await storage.saveLocation(_oldParis);
    await storage.saveActiveLocation(_oldKemer);
  });

  Widget screen(
    MigrationReport report, {
    Future<http.Response> Function(http.Request)? handler,
  }) => wrapWithTheme(
    LocationMigrationScreen(
      report: report,
      locationRepository: LocationRepository(
        storage: storage,
        clearPrayerCache: (id) async => cleared.add(id),
      ),
      placesApi: PlacesApi(
        client: MockClient(handler ?? (_) async => http.Response('', 500)),
        baseUrl: 'https://t',
      ),
      onFinished: () async => finished++,
    ),
  );

  testWidgets(
    'Oneriden secmek konumu esler, aktif kaydi gunceller, onbellegi temizler',
    (tester) async {
      final report = MigrationReport([
        MigrationItem(
          location: _oldKemer,
          decision: MigrationDecision.ambiguous,
          suggestions: [
            _match(1, 'Kemer', 'Burdur'),
            _match(2, 'Kemer', 'Antalya'),
          ],
        ),
      ]);
      await tester.pumpWidget(screen(report));
      await tester.pump();

      expect(find.text('Konumlarını doğrula'), findsOneWidget);
      expect(find.text('Tatil'), findsOneWidget);
      expect(
        find.text('Birden fazla eşleşme var; doğru ilçeyi seç.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Kemer, Antalya'));
      await tester.pumpAndSettle();

      final saved = await storage.getSavedLocations();
      expect(
        saved.any((l) => l.id == 'photon-3'),
        isFalse,
        reason: 'eski kimlik silinir',
      );
      final mapped = saved.firstWhere((l) => l.id == 'diyanet-2');
      expect(mapped.cityId, 2);
      expect(mapped.type, LocationType.manual);
      expect(mapped.customName, 'Tatil');
      expect((await storage.getActiveLocation())?.id, 'diyanet-2');
      expect(cleared, ['diyanet-2']);
      expect(finished, 1, reason: 'son oge cozulunce biter');
    },
  );

  testWidgets('Desteklenmeyen aktif olmayan konum silinebilir', (tester) async {
    final report = MigrationReport([
      MigrationItem(
        location: _oldParis,
        decision: MigrationDecision.unsupported,
      ),
    ]);
    await tester.pumpWidget(screen(report));
    await tester.pump();

    expect(find.text('Bu konum artık desteklenmiyor.'), findsOneWidget);
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();

    expect((await storage.getSavedLocations()).map((l) => l.id), ['photon-3']);
    expect((await storage.getActiveLocation())?.id, 'photon-3');
    expect(finished, 1);
  });

  testWidgets('Aktif konumda Sil yoktur; Baska ilce ara panelden secim yapar', (
    tester,
  ) async {
    final report = MigrationReport([
      MigrationItem(
        location: _oldKemer,
        decision: MigrationDecision.unsupported,
      ),
    ]);
    await tester.pumpWidget(
      screen(
        report,
        handler: (_) async => http.Response(
          jsonEncode({
            'query': '',
            'results': [_json(2, 'Kemer', 'Antalya')],
          }),
          200,
          headers: _headers,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sil'), findsNothing);
    expect(find.text('Aktif konum silinemez; bir ilçe seç.'), findsOneWidget);

    await tester.tap(find.text('Başka ilçe ara'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kemer, Antalya'));
    await tester.pumpAndSettle();

    expect((await storage.getActiveLocation())?.cityId, 2);
    expect(finished, 1);
  });

  testWidgets(
    'Birden fazla oge: biri cozulunce ekran kalir, hepsi bitince biter',
    (tester) async {
      final report = MigrationReport([
        MigrationItem(
          location: _oldKemer,
          decision: MigrationDecision.ambiguous,
          suggestions: [_match(2, 'Kemer', 'Antalya')],
        ),
        MigrationItem(
          location: _oldParis,
          decision: MigrationDecision.unsupported,
        ),
      ]);
      await tester.pumpWidget(screen(report));
      await tester.pump();

      await tester.tap(find.text('Kemer, Antalya'));
      await tester.pumpAndSettle();
      expect(finished, 0);
      expect(find.text('Bu konum artık desteklenmiyor.'), findsOneWidget);

      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      expect(finished, 1);
    },
  );
}
