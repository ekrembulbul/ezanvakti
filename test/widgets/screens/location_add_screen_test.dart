import 'dart:convert';

import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/providers/app_state.dart';
import 'package:ezanvakti/features/location/data/gps_location_service.dart';
import 'package:ezanvakti/features/location/data/places_api.dart';
import 'package:ezanvakti/features/location/domain/location_repository.dart';
import 'package:ezanvakti/presentation/screens/location_add_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/fakes.dart';
import '../theme_harness.dart';

const _headers = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _match(
  int id,
  String name,
  String state, {
  bool centre = false,
  double lat = 41.0,
  double lon = 29.0,
}) => {
  'id': id,
  'name': name,
  'stateName': state,
  'displayName': centre ? '$name (Merkez)' : '$name, $state',
  'stateId': 539,
  'countryId': 2,
  'isCentre': centre,
  'latitude': lat,
  'longitude': lon,
};

http.Response _search(List<Map<String, dynamic>> results) => http.Response(
  jsonEncode({'query': '', 'results': results}),
  200,
  headers: _headers,
);

/// Geolocator'a dokunmadan GPS sonucu verir.
class _FakeGps extends GpsLocationService {
  final Future<GpsResolution> Function() onLocate;

  _FakeGps(this.onLocate)
    : super(
        api: PlacesApi(client: MockClient((_) async => http.Response('', 500))),
      );

  @override
  Future<GpsResolution> locate({Future<bool> Function()? requestPermission}) =>
      onLocate();
}

const _sile = Location(
  id: 'gps',
  province: 'İstanbul',
  district: 'Şile',
  type: LocationType.gps,
  cityId: 9547,
  latitude: 41.2,
  longitude: 29.7,
  displayLabel: 'Şile, İstanbul',
);

void main() {
  late FakeStorage storage;
  late List<String> cleared;
  late AppState appState;

  setUp(() {
    storage = FakeStorage();
    cleared = [];
    appState = AppState();
  });

  Widget screen({
    required Future<http.Response> Function(http.Request) handler,
    Future<GpsResolution> Function()? gps,
  }) => wrapWithTheme(
    LocationAddScreen(
      locationRepository: LocationRepository(
        storage: storage,
        clearPrayerCache: (id) async => cleared.add(id),
      ),
      placesApi: PlacesApi(client: MockClient(handler), baseUrl: 'https://t'),
      gpsService: _FakeGps(
        gps ?? () async => throw StateError('gps not expected'),
      ),
    ),
    appState: appState,
  );

  testWidgets(
    'Aramadan secip kaydetmek manuel Diyanet konumu yazar ve aktif yapar',
    (tester) async {
      await tester.pumpWidget(
        screen(
          handler: (_) async => _search([
            _match(9547, 'Şile', 'İstanbul', lat: 41.1758, lon: 29.6127),
          ]),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Şile, İstanbul'));
      await tester.pump();
      expect(find.text('Kaydet'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Özel İsim (Opsiyonel)'),
        'Yazlık',
      );
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      final saved = (await storage.getSavedLocations()).single;
      expect(saved.id, 'diyanet-9547');
      expect(saved.cityId, 9547);
      expect(saved.type, LocationType.manual);
      expect(saved.latitude, 41.1758);
      expect(saved.customName, 'Yazlık');
      expect(saved.displayLabel, 'Şile, İstanbul');
      expect((await storage.getActiveLocation())?.id, 'diyanet-9547');
      expect(appState.activeLocation?.id, 'diyanet-9547');
      expect(cleared, ['diyanet-9547']);
    },
  );

  testWidgets('Konumumu kullan: onay bandi, Onayla GPS kaydini yazar', (
    tester,
  ) async {
    await tester.pumpWidget(
      screen(
        handler: (_) async => _search([]),
        gps: () async => const GpsResolution(location: _sile, distanceKm: 3.1),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Konumumu kullan'));
    await tester.pump();

    expect(
      find.text('Vakitler Şile, İstanbul için gösterilecek'),
      findsOneWidget,
    );
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();

    final saved = (await storage.getSavedLocations()).single;
    expect(saved.id, 'gps');
    expect(saved.type, LocationType.gps);
    expect(saved.cityId, 9547);
    expect(saved.latitude, 41.2);
    expect(appState.activeLocation?.id, 'gps');
    expect(cleared, ['gps']);
  });

  testWidgets('Degistir bandi kapatir, arama kalir', (tester) async {
    await tester.pumpWidget(
      screen(
        handler: (_) async => _search([]),
        gps: () async => const GpsResolution(location: _sile, distanceKm: 1),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Konumumu kullan'));
    await tester.pump();

    await tester.tap(find.text('Değiştir'));
    await tester.pump();

    expect(find.textContaining('için gösterilecek'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(await storage.getSavedLocations(), isEmpty);
  });

  testWidgets('Kapsama disi GPS anlasilir hata gosterir', (tester) async {
    await tester.pumpWidget(
      screen(
        handler: (_) async => _search([]),
        gps: () async => throw NoCoverageException(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Konumumu kullan'));
    await tester.pump();

    expect(
      find.text('Bu bölge henüz desteklenmiyor; ilçeni ara ve seç.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget, reason: 'arama acik kalir');
  });

  testWidgets('Listeden acildiginda kayit sonrasi konumla geri doner', (
    tester,
  ) async {
    Object? popped;
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              popped = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LocationAddScreen(
                    locationRepository: LocationRepository(storage: storage),
                    placesApi: PlacesApi(
                      client: MockClient(
                        (_) async => _search([
                          _match(9206, 'Ankara', 'Ankara', centre: true),
                        ]),
                      ),
                      baseUrl: 'https://t',
                    ),
                    gpsService: _FakeGps(() async => throw StateError('x')),
                    fromLocationList: true,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
        appState: appState,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ankara (Merkez)'));
    await tester.pump();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(popped, isA<Location>());
    expect((popped as Location).cityId, 9206);
    expect(
      appState.activeLocation,
      isNull,
      reason: 'listeden acilinca aktif konumu cagiran degistirir',
    );
  });
}
