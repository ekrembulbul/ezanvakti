import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `SwitchListTile`, arka plan rengi olan bir `Container`'in dogrudan cocugu
/// oldugunda Flutter "ListTile background color or ink splashes may be
/// invisible" assertion'i atar. Ripple gorunmez olur ve o ekrani ziyaret eden
/// butun integration testler duser.
///
/// Asagidaki iki test, sorunun gercek oldugunu ve cozumun ise yaradigini
/// birlikte belgeler.
Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      ),
    ),
  );
}

void main() {
  final tile = SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: const Text('Genel hesaplama ayarını kullan'),
    value: true,
    onChanged: (_) {},
  );

  testWidgets('renkli kapsayicinin dogrudan cocugu olan SwitchListTile hata atar', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(tile));

    expect(tester.takeException(), isA<FlutterError>());
  });

  testWidgets('transparent Material ile sarilmis SwitchListTile hata atmaz', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(Material(type: MaterialType.transparency, child: tile)),
    );

    expect(tester.takeException(), isNull);
  });
}
