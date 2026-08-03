import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/presentation/widgets/common/grouped_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

/// Ekranin tamami repository'ye bagli; burada satirin tasidigi bilgi ve
/// yinelenmeyen etiket kurali dogrulaniyor.
void main() {
  testWidgets('Aktif konum satiri rozetle isaretlenir', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        GroupedList(
          children: [
            GroupedRow(
              icon: Icons.location_on_rounded,
              title: const Text('Kadıköy, İstanbul'),
              subtitle: Text(LocationType.manual.displayName),
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

  test('Konum turu alt satir icin okunabilir etiket veriyor', () {
    expect(LocationType.gps.displayName, 'GPS Konumu');
    expect(LocationType.manual.displayName, 'Manuel');
  });
}
