import 'dart:convert';

import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/features/location/data/places_api.dart';
import 'package:ezanvakti/features/location/domain/location_repository.dart';
import 'package:ezanvakti/presentation/screens/location_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/fakes.dart';
import '../theme_harness.dart';

const _headers = {'content-type': 'application/json; charset=utf-8'};

const _sile = Location(
  id: 'diyanet-9547',
  province: 'İstanbul',
  district: 'Şile',
  cityId: 9547,
  stateId: 539,
  countryId: 2,
  customName: 'Yazlık',
  latitude: 41.17,
  longitude: 29.61,
  displayLabel: 'Şile, İstanbul',
);

http.Response _silivri(http.Request _) => http.Response(
  jsonEncode({
    'query': '',
    'results': [
      {
        'id': 9548,
        'name': 'Silivri',
        'stateName': 'İstanbul',
        'displayName': 'Silivri, İstanbul',
        'stateId': 539,
        'countryId': 2,
        'isCentre': false,
        'latitude': 41.07,
        'longitude': 28.24,
      },
    ],
  }),
  200,
  headers: _headers,
);

void main() {
  late FakeStorage storage;
  late List<String> cleared;
  Location? popped;

  setUp(() async {
    storage = FakeStorage();
    cleared = [];
    popped = null;
    await storage.saveLocation(_sile);
  });

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<Location>(
                MaterialPageRoute(
                  builder: (_) => LocationEditScreen(
                    locationRepository: LocationRepository(
                      storage: storage,
                      clearPrayerCache: (id) async => cleared.add(id),
                    ),
                    placesApi: PlacesApi(
                      client: MockClient((req) async => _silivri(req)),
                      baseUrl: 'https://t',
                    ),
                    location: _sile,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Ilceyi degistir: yeni ilce secilince kimlik ve ad korunur, onbellek temizlenir',
    (tester) async {
      await openScreen(tester);

      await tester.tap(find.text('İlçeyi değiştir'));
      // Panel açılışta boş sorgu atar; cevap bir sonraki frame'de gelir.
      await tester.pumpAndSettle();
      await tester.tap(find.text('Silivri, İstanbul'));
      await tester.pump();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      final saved = (await storage.getSavedLocations()).single;
      expect(saved.id, 'diyanet-9547', reason: 'kayit kimligi korunur');
      expect(saved.cityId, 9548);
      expect(saved.district, 'Silivri');
      expect(saved.latitude, 41.07);
      expect(saved.customName, 'Yazlık');
      expect(saved.displayLabel, 'Silivri, İstanbul');
      expect(cleared, ['diyanet-9547']);
      expect(popped?.cityId, 9548);
    },
  );

  testWidgets('Yalniz ozel ad degisince ilce ve onbellek dokunulmaz', (
    tester,
  ) async {
    await openScreen(tester);

    await tester.enterText(find.byType(TextField), 'Ev');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final saved = (await storage.getSavedLocations()).single;
    expect(saved.customName, 'Ev');
    expect(saved.cityId, 9547);
    expect(cleared, isEmpty);
  });

  testWidgets('Ozel ad silinince null yazilir', (tester) async {
    await openScreen(tester);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect((await storage.getSavedLocations()).single.customName, isNull);
  });
}
