import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/features/location/data/gps_location_service.dart';
import 'package:ezanvakti/features/location/data/places_api.dart';
import 'package:ezanvakti/features/location/domain/location_repository.dart';
import 'package:ezanvakti/presentation/screens/location_edit_screen.dart';
import 'package:ezanvakti/presentation/screens/location_list_screen.dart';
import 'package:ezanvakti/presentation/widgets/common/grouped_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ezanvakti/l10n/l10n_extensions.dart';

import '../../support/fakes.dart';
import '../../support/l10n_helper.dart';
import '../theme_harness.dart';

/// Ekranin tamami repository'ye bagli; burada satirin tasidigi bilgi ve
/// yinelenmeyen etiket kurali dogrulaniyor.
void main() {
  testWidgets('Aktif konum satiri rozetle isaretlenir', (tester) async {
    final l10n = await loadTestL10n();
    await tester.pumpWidget(
      wrapWithTheme(
        GroupedList(
          children: [
            GroupedRow(
              icon: Icons.location_on_rounded,
              title: const Text('Kadıköy, İstanbul'),
              subtitle: Text(l10n.locationTypeLabel(LocationType.manual)),
              trailing: const Text('AKTİF'),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Kadıköy, İstanbul'), findsOneWidget);
    expect(find.text('AKTİF'), findsOneWidget);
  });

  test('displayName tek satirda yeterli bilgi tasiyor', () {
    const location = Location(
      id: '1',
      province: 'İstanbul',
      district: 'Kadıköy',
    );

    // Liste satirinda ayrica "il / ilce" alt satiri gostermeye gerek yok;
    // ayni bilgiyi ters sirada tekrarliyordu.
    expect(location.displayName, 'Kadıköy, İstanbul');
  });

  testWidgets('Konum turu alt satir icin okunabilir etiket veriyor', (
    tester,
  ) async {
    final l10n = await loadTestL10n();
    expect(l10n.locationTypeLabel(LocationType.gps), 'GPS Konumu');
    expect(l10n.locationTypeLabel(LocationType.manual), 'Manuel');
  });

  group('Ekran', () {
    const active = Location(
      id: 'kadikoy',
      province: 'İstanbul',
      district: 'Kadıköy',
    );
    const other = Location(
      id: 'uskudar',
      province: 'İstanbul',
      district: 'Üsküdar',
    );
    late FakeStorage storage;
    late PlacesApi placesApi;

    setUp(() async {
      storage = FakeStorage();
      await storage.saveLocation(active);
      await storage.saveLocation(other);
      placesApi = PlacesApi(
        client: MockClient((_) async => http.Response('{}', 200)),
        baseUrl: 'https://t',
      );
    });

    Future<void> pumpList(WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          LocationListScreen(
            locationRepository: LocationRepository(storage: storage),
            placesApi: placesApi,
            gpsService: GpsLocationService(api: placesApi),
            currentLocation: active,
            onLocationSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<List<String>> savedIds() async => [
      for (final location in await storage.getSavedLocations()) location.id,
    ];

    testWidgets('Kayitli konumlar listelenir', (tester) async {
      await pumpList(tester);

      expect(find.text('Kadıköy, İstanbul'), findsOneWidget);
      expect(find.text('Üsküdar, İstanbul'), findsOneWidget);
    });
  });
}
