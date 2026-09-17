/// Türkçe adları karşılaştırma anahtarına indirir: İ→i, I→ı kurallarıyla küçük
/// harf, sonra ASCII katlama (ç→c, ğ→g, ı→i, ö→o, ş→s, ü→u, şapkalar) ve
/// harf/rakam dışı her şey atılır. Sunucunun arama anahtarıyla aynı kural;
/// migrasyonda "kayıtlı ad" ile "sunucu adı" böyle karşılaştırılır.
String foldTR(String input) {
  final lower = input.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  const map = {
    'ç': 'c',
    'ğ': 'g',
    'ı': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
    'â': 'a',
    'î': 'i',
    'û': 'u',
  };
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    final mapped = map[ch] ?? ch;
    final code = mapped.codeUnitAt(0);
    final isAlnum =
        (code >= 0x61 && code <= 0x7a) || (code >= 0x30 && code <= 0x39);
    if (isAlnum) buffer.write(mapped);
  }
  return buffer.toString();
}
