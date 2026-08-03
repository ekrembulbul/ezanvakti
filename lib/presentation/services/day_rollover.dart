import '../../core/models/prayer_time.dart';

/// Gün dönümünden sonra beklenen küçük pay.
///
/// Tam gece yarısında uyanmak, timer birkaç milisaniye erken tetiklenirse hâlâ
/// dünün içinde kalma riski taşır.
const Duration kMidnightMargin = Duration(seconds: 1);

/// [now]'dan bir sonraki gece yarısına kalan süre (+[kMidnightMargin]).
///
/// Vakit tablosu **miladi takvim gününe** bağlıdır: `adhan` ailesi de Awqat
/// Salah ucu da vakitleri tarih başına verir. Dolayısıyla gün dönümü bir
/// vakitte değil, gece yarısında olur ve o an veri tazelenmelidir.
///
/// Gün uzunluğu takvimden hesaplanır; DST günleri 23 veya 25 saat sürer.
Duration delayToNextMidnight(DateTime now) {
  final nextMidnight = DateTime(now.year, now.month, now.day + 1);
  return nextMidnight.difference(now) + kMidnightMargin;
}

/// Elde tutulan vakit verisi bugüne değil, geçmiş bir güne mi ait?
///
/// Uygulama askıdayken timer tetiklenmez; ön plana dönüşte bu kontrol gün
/// dönümünü kaçırmamayı sağlar.
bool isPrayerDataStale(PrayerTime? today, DateTime now) {
  if (today == null) return false;
  final loaded = today.date;
  return loaded.year != now.year ||
      loaded.month != now.month ||
      loaded.day != now.day;
}
