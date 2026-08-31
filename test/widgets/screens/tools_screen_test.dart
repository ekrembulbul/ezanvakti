import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/providers/app_state.dart';
import 'package:ezanvakti/features/qibla/data/heading_service.dart';
import 'package:ezanvakti/presentation/screens/qibla_screen.dart';
import 'package:ezanvakti/presentation/screens/tools_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  Future<void> pumpTools(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrapWithTheme(const ToolsScreen()));
    await tester.pump();
  }

  testWidgets('Uc arac satiri cizilir', (tester) async {
    await pumpTools(tester);
    expect(find.text('Kıble'), findsOneWidget);
    expect(find.text('Namaz takibi'), findsOneWidget);
    expect(find.text('Zikirmatik'), findsOneWidget);
  });

  group('QiblaScreen', () {
    Future<void> pumpQibla(
      WidgetTester tester, {
      Location? location,
      Stream<HeadingReading>? headings,
    }) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapWithTheme(
          QiblaScreen(location: location, headings: headings),
          appState: AppState(),
        ),
      );
      await tester.pump();
    }

    final istanbul = Location(
      id: 'l1',
      province: 'İstanbul',
      district: 'Fatih',
      type: LocationType.manual,
      latitude: 41.0082,
      longitude: 28.9784,
    );

    testWidgets('konum yoksa aciklayici bos durum', (tester) async {
      await pumpQibla(tester, location: null);
      expect(find.text('Konum gerekiyor'), findsOneWidget);
      expect(find.byKey(kQiblaArrowKey), findsNothing);
    });

    testWidgets('koordinatsiz konum da bos durum gosterir', (tester) async {
      await pumpQibla(
        tester,
        location: Location(
          id: 'l2',
          province: 'X',
          district: 'Y',
          type: LocationType.manual,
        ),
      );
      expect(find.text('Konum gerekiyor'), findsOneWidget);
    });

    testWidgets('konum varken aci gosterilir', (tester) async {
      await pumpQibla(tester, location: istanbul);
      // Istanbul kiblesi 151.62 derece; ekranda yuvarlanmis hali.
      expect(find.text('152°'), findsOneWidget);
    });

    testWidgets('kalibrasyon gerekiyorsa uyari cikar', (tester) async {
      await pumpQibla(
        tester,
        location: istanbul,
        headings: Stream.value(
          const HeadingReading(degrees: 10, accuracy: -1),
        ),
      );
      await tester.pump();
      expect(find.byKey(kQiblaCalibrationKey), findsOneWidget);
    });

    testWidgets('hizalaninca yon talimati yerine onay yazar', (tester) async {
      await pumpQibla(
        tester,
        location: istanbul,
        // Istanbul kiblesi ~151; ayni yone bakan cihaz hizali sayilir.
        headings: Stream.value(
          const HeadingReading(degrees: 151, accuracy: 3),
        ),
      );
      await tester.pump();
      expect(find.text('Kıbleye dönüksün'), findsOneWidget);
    });
  });
}
