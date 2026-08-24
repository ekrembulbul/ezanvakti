import 'dart:async';

import 'package:ezanvakti/presentation/widgets/missions/qr_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  late StreamController<String> codes;
  late BuildContext pageContext;
  late Future<String?> scanned;

  setUp(() => codes = StreamController<String>.broadcast());
  tearDown(() => codes.close());

  /// Okuyucuyu bir sayfanın üstünde açar. [scanned], okuyucu kapanınca
  /// dönen kodla tamamlanır.
  Future<void> openScanner(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) {
            pageContext = context;
            return const Text('alarm-ekrani');
          },
        ),
      ),
    );

    scanned = Navigator.of(pageContext).push<String>(
      MaterialPageRoute(builder: (_) => QrScannerScreen(codes: codes.stream)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Okunan ilk kod geri doner', (tester) async {
    await openScanner(tester);

    codes.add('mutfak-kapisi');
    await tester.pumpAndSettle();

    expect(await scanned, 'mutfak-kapisi');
    expect(find.text('alarm-ekrani'), findsOneWidget);
  });

  testWidgets('Ayni kod tekrar okunursa alttaki ekran kapanmaz', (
    tester,
  ) async {
    await openScanner(tester);

    // Kamera kod goruste kaldigi surece her karede okuyor; kapanis aninda da
    // birkac okuma daha geliyor.
    codes
      ..add('mutfak-kapisi')
      ..add('mutfak-kapisi')
      ..add('baska-kod');
    await tester.pumpAndSettle();

    expect(await scanned, 'mutfak-kapisi', reason: 'ilk kod kazanir');
    expect(
      find.text('alarm-ekrani'),
      findsOneWidget,
      reason:
          'Her okuma pop cagirinca okuyucunun altindaki alarm ekrani da '
          'yigindan dusuyor ve ekran dokunmalara cevap vermez oluyordu',
    );
  });

  testWidgets('Bos kod yok sayilir', (tester) async {
    await openScanner(tester);

    codes.add('');
    await tester.pumpAndSettle();
    expect(find.text('Kodu okut'), findsOneWidget, reason: 'okuyucu acik kalir');

    codes.add('gercek-kod');
    await tester.pumpAndSettle();

    expect(await scanned, 'gercek-kod');
  });
}
