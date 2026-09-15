/// Saat okunuşuna gelen Türkçe bulunma eki: "18:38'de", "19:23'te", "18:40'ta".
///
/// Ek, saatin okunuşundaki **son kelimeye** göre seçilir: dakika sıfır değilse
/// dakika, sıfırsa saat okunur ("on sekiz otuz sekiz-de", "on üç-te"). Son
/// kelime birler basamağıdır; birler sıfırsa onlar basamağı. Ünlü uyumu ve
/// ünsüz sertleşmesi kelimeye gömülü olduğundan tablo yeterlidir.
String turkishLocativeSuffix({required int hour, required int minute}) {
  if (hour < 0 || hour > 23) {
    throw RangeError.range(hour, 0, 23, 'hour');
  }
  if (minute < 0 || minute > 59) {
    throw RangeError.range(minute, 0, 59, 'minute');
  }
  final spoken = minute == 0 ? hour : minute;
  final units = spoken % 10;
  final suffix = units != 0 ? _unitsSuffix[units]! : _tensSuffix[spoken ~/ 10]!;
  return "'$suffix";
}

/// bir, iki, üç, dört, beş, altı, yedi, sekiz, dokuz.
const Map<int, String> _unitsSuffix = {
  1: 'de',
  2: 'de',
  3: 'te',
  4: 'te',
  5: 'te',
  6: 'da',
  7: 'de',
  8: 'de',
  9: 'da',
};

/// sıfır, on, yirmi, otuz, kırk, elli.
const Map<int, String> _tensSuffix = {
  0: 'da',
  1: 'da',
  2: 'de',
  3: 'da',
  4: 'ta',
  5: 'de',
};
