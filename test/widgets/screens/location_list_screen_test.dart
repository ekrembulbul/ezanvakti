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

    testWidgets(
      'Kaydırma yok; aktif olmayan konumda menü siler, Geri al geri getirir',
      (tester) async {
        await pumpList(tester);
        expect(find.byType(Dismissible), findsNothing);
        expect(
          find.text('Aktif olmayan konumu silmek için satıra basılı tut.'),
          findsOneWidget,
        );

        await tester.longPress(find.text('Üsküdar, İstanbul'));
        await tester.pumpAndSettle();
        expect(find.text('ÜSKÜDAR, İSTANBUL'), findsOneWidget);
        expect(find.text('Kopyala'), findsNothing);
        await tester.tap(find.text('Sil'));
        await tester.pumpAndSettle();

        expect(await savedIds(), ['kadikoy']);
        expect(find.text('Üsküdar, İstanbul'), findsNothing);

        await tester.tap(find.text('Geri al'));
        await tester.pumpAndSettle();
        expect(await savedIds(), containsAll(['kadikoy', 'uskudar']));
        expect(find.text('Üsküdar, İstanbul'), findsOneWidget);
      },
    );

    testWidgets('Listeden çıkıldıktan sonra "Geri al" konumu geri getirir', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LocationListScreen(
                    locationRepository: LocationRepository(storage: storage),
                    placesApi: placesApi,
                    gpsService: GpsLocationService(api: placesApi),
                    currentLocation: active,
                    onLocationSelected: (_) {},
                  ),
                ),
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Üsküdar, İstanbul'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      expect(await savedIds(), ['kadikoy']);

      Navigator.of(tester.element(find.byType(LocationListScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(LocationListScreen), findsNothing);

      // Çubuk kök ScaffoldMessenger'da; liste kapandıktan sonra da görünür.
      await tester.tap(find.text('Geri al'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(await savedIds(), containsAll(['kadikoy', 'uskudar']));
    });

    testWidgets('Aktif konumda basılı tutma menü açmaz', (tester) async {
      await pumpList(tester);

      await tester.longPress(find.text('Kadıköy, İstanbul'));
      await tester.pumpAndSettle();

      expect(find.text('Sil'), findsNothing);
    });

    testWidgets(
      '"Konumu sil" yalnız aktif olmayan konumda; ekranı kapatıp siler',
      (tester) async {
        await pumpList(tester);
        Finder editIconOf(String name) => find.descendant(
          of: find.widgetWithText(GroupedRow, name),
          matching: find.byIcon(Icons.edit_outlined),
        );

        await tester.tap(editIconOf('Kadıköy, İstanbul'));
        await tester.pumpAndSettle();
        expect(find.byType(LocationEditScreen), findsOneWidget);
        expect(find.text('Konumu sil'), findsNothing);
        Navigator.of(tester.element(find.byType(LocationEditScreen))).pop();
        await tester.pumpAndSettle();

        await tester.tap(editIconOf('Üsküdar, İstanbul'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Konumu sil'));
        await tester.pumpAndSettle();

        expect(find.byType(LocationEditScreen), findsNothing);
        expect(await savedIds(), ['kadikoy']);
        expect(find.text('Geri al'), findsOneWidget);
      },
    );
  });
}
