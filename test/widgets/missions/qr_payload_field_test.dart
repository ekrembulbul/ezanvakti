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

  testWidgets('Okutma dugmesi alanin yaninda ve ondan kucuk', (tester) async {
    await pump(tester);

    final field = tester.getRect(find.byKey(kQrPayloadFieldKey));
    final button = tester.getRect(find.byKey(kQrScanButtonKey));

    expect(button.left, greaterThan(field.right), reason: 'alanin saginda');
    expect(button.width, button.height, reason: 'kare');
    expect(
      button.height,
      lessThan(field.height),
      reason:
          'Alanla ayni yukseklige uzatilinca ikincil eylem metin alanindan '
          'daha agir gorunuyordu',
    );
    expect(
      button.center.dy,
      moreOrLessEquals(field.center.dy, epsilon: 1),
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
