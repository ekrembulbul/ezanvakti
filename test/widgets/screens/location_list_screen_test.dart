import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/presentation/widgets/common/grouped_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ezanvakti/l10n/l10n_extensions.dart';

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
}
