import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kaynak kodda kullanıcıya görünen **sabit Türkçe metin** kalmadığını
/// doğrular.
///
/// Çeviri işi bir kez yapılıp bırakılırsa, sonraki her ekranda yeniden Türkçe
/// metin sızar. Bu test o sızıntıyı derleme değil, test aşamasında yakalar.
///
/// Yorum satırları taranmaz: kod dokümantasyonu Türkçe (PRODUCT_SPEC).
/// İstisnalar aşağıda tek tek gerekçeleriyle listelidir.
void main() {
  /// Türkçe'ye özgü harfler; İngilizce ve Arapça metinlerde bulunmaz.
  final turkish = RegExp('[çğıöşüÇĞİÖŞÜ]');

  /// Tek ve çift tırnaklı string literal'ler.
  final literal = RegExp(r"'((?:[^'\\]|\\.)*)'|" r'"((?:[^"\\]|\\.)*)"');

  /// Çevrilmemesi **doğru** olan yerler.
  const allowed = <String, String>{
    'lib/core/models/calculation_params.dart':
        'Kurum adları özel isimdir: "Diyanet İşleri Başkanlığı" çevrilmez.',
  };

  test('lib/ altinda sabit Turkce kullanici metni yok', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // Üretilen çeviri dosyaları doğal olarak Türkçe içerir.
      if (entity.path.contains('/l10n/')) continue;
      if (allowed.containsKey(entity.path)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//')) continue;
        final code = line.replaceAll(RegExp(r'//.*$'), '');

        for (final match in literal.allMatches(code)) {
          final value = match.group(1) ?? match.group(2) ?? '';
          if (value.length < 2 || !turkish.hasMatch(value)) continue;
          offenders.add('${entity.path}:${i + 1}: $value');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Bu metinler ARB dosyalarina tasinmali ve context.l10n ile '
          'okunmali:\n${offenders.join('\n')}',
    );
  });

  test('istisna listesindeki dosyalar hala var', () {
    for (final path in allowed.keys) {
      expect(
        File(path).existsSync(),
        isTrue,
        reason: '$path silinmis; istisna listesi guncellenmeli',
      );
    }
  });
}
