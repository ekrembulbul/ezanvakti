import 'package:ezanvakti/presentation/widgets/missions/qr_payload_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: QrPayloadField(
              controller: controller,
              scanOverride: (_) async => 'okunan-kod',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Okutma dugmesi alanla ayni yukseklikte bir kare', (tester) async {
    await pump(tester);

    // Cizilen kutu olculuyor: alanin yerlesim yuksekligi 56 olsa da kutusu
    // icinde ortalanip daha kisa kalabiliyor.
    final field = tester.getRect(find.byType(InputDecorator));
    final button = tester.getRect(find.byKey(kQrScanButtonKey));

    expect(button.left, greaterThan(field.right), reason: 'alanin saginda');
    expect(
      button.height,
      moreOrLessEquals(field.height, epsilon: 0.5),
      reason:
          'Yukseklik IntrinsicHeight ile alandan turetilince dugme alandan '
          'uzun cikiyordu; olcu artik ikisine birden veriliyor',
    );
    expect(
      button.width,
      moreOrLessEquals(button.height, epsilon: 0.5),
      reason: 'kare',
    );
    expect(
      button.center.dy,
      moreOrLessEquals(field.center.dy, epsilon: 0.5),
      reason: 'dikeyde ortali',
    );
  });

  testWidgets('Okutma sonucu alana yazilir', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(kQrScanButtonKey));
    await tester.pumpAndSettle();

    expect(controller.text, 'okunan-kod');
  });

  testWidgets('Ikonun yaninda yazi yok, eylem adi Tooltip ta', (tester) async {
    await pump(tester);

    expect(find.widgetWithText(OutlinedButton, 'Kodu okut'), findsNothing);
    expect(
      find.byTooltip('Kodu okut'),
      findsOneWidget,
      reason: 'ikon tek basina kaldigi icin ad erisilebilirlikte yasamali',
    );
  });
}
