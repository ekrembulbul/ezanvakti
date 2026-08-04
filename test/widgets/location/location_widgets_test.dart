import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/presentation/widgets/location/location_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  testWidgets('LocationChoiceButton baslik ve alt metni gosterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        LocationChoiceButton(
          icon: Icons.search_rounded,
          title: 'Adres Ara',
          subtitle: 'Şehir, ilçe veya yer adıyla ara',
          onTap: () {},
        ),
      ),
    );

    expect(find.text('Adres Ara'), findsOneWidget);
    expect(find.text('Şehir, ilçe veya yer adıyla ara'), findsOneWidget);
  });

  testWidgets('LocationChoiceButton dokunma callback tetikler', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      wrapWithTheme(
        LocationChoiceButton(
          icon: Icons.my_location_rounded,
          title: 'GPS ile Bul',
          subtitle: 'Otomatik konum tespiti',
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.text('GPS ile Bul'));
    expect(tapped, isTrue);
  });

  testWidgets('LocationChoiceButton yuklenirken gosterge cizer', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        LocationChoiceButton(
          icon: Icons.my_location_rounded,
          title: 'Konum Alınıyor...',
          subtitle: 'Otomatik konum tespiti',
          isLoading: true,
          onTap: () {},
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('LocationErrorCard hata rengini ColorScheme ten alir', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(const LocationErrorCard(error: 'Konum izni reddedildi.')),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded));
    final scheme = Theme.of(
      tester.element(find.byType(LocationErrorCard)),
    ).colorScheme;

    expect(find.text('Konum izni reddedildi.'), findsOneWidget);
    expect(icon.color, scheme.error);
  });

  testWidgets('LocationSelectionConfirm secilen yerin adini gosterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        const LocationSelectionConfirm(
          location: Location(
            id: '1',
            province: 'İstanbul',
            district: 'Kadıköy',
          ),
        ),
      ),
    );

    // Uygulamanin her yerinde ayni bicim; onay satiri "İstanbul / Kadıköy"
    // seklinde ters sirada ve egik cizgiyle gosteriyordu.
    expect(find.text('Kadıköy, İstanbul'), findsOneWidget);
  });
}
