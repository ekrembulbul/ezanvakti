import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/lat_lon.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/features/location/data/gps_location_service.dart';
import 'package:ezanvakti/features/location/data/places_api.dart';
import 'package:ezanvakti/presentation/services/nearby_mosques_launcher.dart';
import 'package:ezanvakti/presentation/widgets/tools/nearby_mosques_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

class _FakeGps extends GpsLocationService {
  Object? error;
  LatLon position = (lat: 40.5, lon: 29.5);

  _FakeGps()
    : super(
        api: PlacesApi(
          client: MockClient((_) async => http.Response('', 500)),
          baseUrl: 'https://api.test',
        ),
      );

  @override
  Future<LatLon> currentPosition({
    Future<bool> Function()? requestPermission,
    LocationAccuracy accuracy = LocationAccuracy.medium,
    Duration? timeout = const Duration(seconds: 10),
  }) async {
    if (error case final e?) throw e;
    return position;
  }
}

const _kadikoy = Location(
  id: '1',
  province: 'İstanbul',
  district: 'Kadıköy',
  latitude: 41.0,
  longitude: 29.0,
);

void main() {
  late _SettingsStorage storage;
  late _FakeGps gps;
  late List<Uri> opened;
  late Set<String> installed;
  late bool openResult;

  NearbyMosquesLauncher launcher({bool isIOS = false}) => NearbyMosquesLauncher(
    storage: storage,
    isIOS: isIOS,
    osVersion: '26.0',
    canOpen: (uri) async => installed.contains(uri.scheme),
    open: (uri) async {
      opened.add(uri);
      return openResult;
    },
  );

  setUp(() {
    storage = _SettingsStorage();
    gps = _FakeGps();
    opened = [];
    installed = {};
    openResult = true;
  });

  Future<void> start(
    WidgetTester tester, {
    Location location = _kadikoy,
    bool isIOS = false,
  }) async {
    final l = launcher(isIOS: isIOS);
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showNearbyMosquesFlow(
              context,
              location: location,
              launcher: l,
              gps: gps,
            ),
            child: const Text('başlat'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('başlat'));
    await tester.pumpAndSettle();
  }

  testWidgets('vakit konumu koordinatıyla arar', (tester) async {
    await start(tester);
    expect(
      find.text('Vakit konumuna göre (Kadıköy, İstanbul)'),
      findsOneWidget,
    );
    await tester.tap(find.text('Vakit konumuna göre (Kadıköy, İstanbul)'));
    await tester.pumpAndSettle();
    expect(opened.single.toString(), 'geo:41.0,29.0?z=14&q=cami');
  });

  testWidgets('koordinatsız vakit konumunda konum adıyla arar', (tester) async {
    const noCoords = Location(id: '2', province: 'İstanbul', district: 'Şile');
    await start(tester, location: noCoords);
    await tester.tap(find.text('Vakit konumuna göre (Şile, İstanbul)'));
    await tester.pumpAndSettle();
    expect(
      Uri.decodeComponent(opened.single.toString()),
      'geo:0,0?q=cami Şile, İstanbul',
    );
  });

  testWidgets('koordinatsız ve özel adlı konumda ilçe adıyla arar', (
    tester,
  ) async {
    const custom = Location(
      id: '3',
      province: 'İstanbul',
      district: 'Şile',
      customName: 'Ev',
    );
    await start(tester, location: custom);
    await tester.tap(find.text('Vakit konumuna göre (Ev)'));
    await tester.pumpAndSettle();
    expect(
      Uri.decodeComponent(opened.single.toString()),
      'geo:0,0?q=cami Şile, İstanbul',
    );
  });

  testWidgets('konum beklenmeyen hatayla alınamazsa da vakit konumunu önerir', (
    tester,
  ) async {
    gps.error = StateError('platform');
    await start(tester);
    await tester.tap(find.text('Bulunduğum yere göre'));
    await tester.pumpAndSettle();
    expect(
      find.text('Konumun alınamadı. Vakit konumuna göre aransın mı?'),
      findsOneWidget,
    );
  });

  testWidgets('iOS: "her seferinde sor" seçiliyse sorar ama kaydetmez', (
    tester,
  ) async {
    installed = {'comgooglemaps'};
    storage.values['maps_app'] = 'ask';
    await start(tester, isIOS: true);
    await tester.tap(find.text('Vakit konumuna göre (Kadıköy, İstanbul)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google Haritalar'));
    await tester.pumpAndSettle();
    expect(opened.single.scheme, 'comgooglemaps');
    expect(storage.values['maps_app'], 'ask');
  });

  testWidgets('bulunduğum yere göre telefon koordinatıyla arar', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.text('Bulunduğum yere göre'));
    await tester.pumpAndSettle();
    expect(opened.single.toString(), 'geo:40.5,29.5?z=14&q=cami');
  });

  testWidgets('konum alınamazsa vakit konumunu önerir', (tester) async {
    gps.error = const GpsLocationException(GpsLocationService.timeoutKey);
    await start(tester);
    await tester.tap(find.text('Bulunduğum yere göre'));
    await tester.pumpAndSettle();
    expect(
      find.text('Konumun alınamadı. Vakit konumuna göre aransın mı?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Ara'));
    await tester.pumpAndSettle();
    expect(opened.single.toString(), 'geo:41.0,29.0?z=14&q=cami');
  });

  testWidgets('konum alınamayınca vazgeçilirse hiçbir şey açılmaz', (
    tester,
  ) async {
    gps.error = const GpsLocationException(GpsLocationService.servicesOffKey);
    await start(tester);
    await tester.tap(find.text('Bulunduğum yere göre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
  });

  testWidgets('iOS: birden fazla harita varsa sorar ve seçimi hatırlar', (
    tester,
  ) async {
    installed = {'comgooglemaps'};
    await start(tester, isIOS: true);
    await tester.tap(find.text('Vakit konumuna göre (Kadıköy, İstanbul)'));
    await tester.pumpAndSettle();
    expect(find.text('Apple Haritalar'), findsOneWidget);
    await tester.tap(find.text('Google Haritalar'));
    await tester.pumpAndSettle();
    expect(
      opened.single.toString(),
      'comgooglemaps://?q=cami&center=41.0,29.0&zoom=14',
    );
    expect(storage.values['maps_app'], 'google');
  });

  testWidgets('açılamazsa haber verir', (tester) async {
    openResult = false;
    await start(tester);
    await tester.tap(find.text('Vakit konumuna göre (Kadıköy, İstanbul)'));
    await tester.pumpAndSettle();
    expect(find.text('Harita uygulaması açılamadı'), findsOneWidget);
  });
}
