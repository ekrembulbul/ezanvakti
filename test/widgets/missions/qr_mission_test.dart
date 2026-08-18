import 'dart:async';

import 'package:ezanvakti/presentation/widgets/missions/qr_mission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  late StreamController<String> codes;

  setUp(() => codes = StreamController.broadcast());
  tearDown(() => codes.close());

  Widget build({String expected = 'banyo-kapisi', VoidCallback? onCompleted}) =>
      wrapWithTheme(
        QrMission(
          expected: expected,
          onCompleted: onCompleted ?? () {},
          codes: codes.stream,
        ),
      );

  testWidgets('Dogru kod okununca tamamlanir', (tester) async {
    var done = false;
    await tester.pumpWidget(build(onCompleted: () => done = true));
    codes.add('banyo-kapisi');
    await tester.pump();
    expect(done, isTrue);
  });

  testWidgets('Bosluklar affedilir', (tester) async {
    var done = false;
    await tester.pumpWidget(build(onCompleted: () => done = true));
    codes.add('  banyo-kapisi ');
    await tester.pump();
    expect(done, isTrue);
  });

  testWidgets('Yanlis kod tamamlamaz ve uyarir', (tester) async {
    var done = false;
    await tester.pumpWidget(build(onCompleted: () => done = true));
    codes.add('mutfak');
    await tester.pump();

    expect(done, isFalse);
    expect(find.text('Farklı bir kod okundu'), findsOneWidget);
  });

  testWidgets('Kayitli kod yoksa gorev yapilamaz, yol gosterilir', (
    tester,
  ) async {
    await tester.pumpWidget(build(expected: ''));
    expect(find.textContaining('kayıtlı bir QR kod yok'), findsOneWidget);
    expect(find.textContaining('acil çıkışı'), findsOneWidget);
    expect(find.byKey(kQrScannerKey), findsNothing);
  });
}
