import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Manrope, dort statik agirlik yerine tek degisken font olarak gomuldu:
/// 165 KB (statiklerin toplami ~400 KB olurdu) ve agirlik `wght` ekseninden
/// gercek enterpolasyonla geliyor.
void main() {
  test('Manrope degisken fontu assets altinda mevcut', () {
    final font = File('assets/fonts/Manrope-Variable.ttf');

    expect(font.existsSync(), isTrue, reason: 'Manrope-Variable.ttf eksik');
    expect(font.lengthSync(), greaterThan(100000));
  });

  test('OFL lisansi font ile birlikte tutuluyor', () {
    final license = File('assets/fonts/Manrope-OFL.txt');

    expect(license.existsSync(), isTrue);
    expect(license.readAsStringSync(), contains('SIL OPEN FONT LICENSE'));
  });

  test('pubspec Manrope ailesini tanimliyor', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('family: Manrope'));
    expect(pubspec, contains('assets/fonts/Manrope-Variable.ttf'));
  });
}
