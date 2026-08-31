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

  /// Sadece ASCII harflerden oluşan Türkçe kelimeler. Harf taraması bunları
  /// göremiyor; `Text('Ayarlar')` gibi sızıntılar bu yüzden gözden kaçtı.
  /// Listeye yalnızca İngilizce'de başka anlamı olmayan kelimeler girer —
  /// "Alarm" gibi iki dilde de aynı yazılanlar yanlış alarm üretir.
  const asciiTurkishWords = <String>[
    'Ayarlar', 'Kapat', 'Ertele', 'Iptal', 'Tamam', 'Kaydet', 'Vazgec',
    'Duzenle', 'Ekle', 'Yenile', 'Devam', 'Geri', 'Namaz', 'Vakit',
    'Vakitler', 'Ezan', 'Konum', 'Sehir', 'Ilce', 'Bildirim', 'Bugun',
    'Yarin', 'Dun', 'Simdi', 'Hata', 'Uyari', 'Acik', 'Kapali', 'Yok',
    'Evet', 'Hayir', 'hak', 'kez', 'dk',
  ];
  final asciiTurkish = RegExp(
    r'\b(?:' + asciiTurkishWords.join('|') + r')\b',
    caseSensitive: false,
  );

  /// Tek ve çift tırnaklı string literal'ler.
  final literal = RegExp(r"'((?:[^'\\]|\\.)*)'|" r'"((?:[^"\\]|\\.)*)"');

  /// Çevrilmemesi **doğru** olan yerler.
  const allowed = <String, String>{
    'lib/core/models/calculation_params.dart':
        'Kurum adları özel isimdir: "Diyanet İşleri Başkanlığı" çevrilmez.',
    'lib/features/location/data/photon_geocoding_service.dart':
        'User-Agent başlığı sunucuya gider, kullanıcıya gösterilmez.',
    'lib/presentation/services/calendar_share_service.dart':
        'Dosya adı ASCII bir slug; çeviriyle değişmemesi gerekiyor.',
  };

  /// Log çağrıları: mesajlar geliştirici içindir, çevrilmez.
  final logCall = RegExp(r'\b(?:_?logger|AppLogger\(\))\.\w+\(|debugPrint\(');

  test('lib/ altinda sabit Turkce kullanici metni yok', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // Üretilen çeviri dosyaları doğal olarak Türkçe içerir.
      if (entity.path.contains('/l10n/')) continue;
      if (allowed.containsKey(entity.path)) continue;

      final lines = entity.readAsLinesSync();
      // Log çağrısı birden çok satıra yayılabiliyor; kapanışa kadar atlanır.
      var inLogCall = false;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (inLogCall) {
          if (line.contains(');')) inLogCall = false;
          continue;
        }
        if (logCall.hasMatch(line)) {
          inLogCall = !line.contains(');');
          continue;
        }
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//')) continue;
        final code = line.replaceAll(RegExp(r'//.*$'), '');

        for (final match in literal.allMatches(code)) {
          final value = match.group(1) ?? match.group(2) ?? '';
          if (value.length < 2) continue;
          if (!turkish.hasMatch(value) && !asciiTurkish.hasMatch(value)) {
            continue;
          }
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
