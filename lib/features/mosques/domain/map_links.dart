/// Harita uygulamalarında "şu noktanın çevresinde ara" bağlantıları.
///
/// Kaynaklar (2026-10-01'de doğrulandı):
/// - Apple, iOS 18.4+: https://developer.apple.com/documentation/mapkit/unified-map-urls
///   (`/search?query=&center=&span=`)
/// - Apple, eski biçim: Apple Map Links arşivi (`q`, `sll`, `z`)
/// - Google iOS: https://developers.google.com/maps/documentation/urls/ios-urlscheme
///   (`comgooglemaps://?q=&center=&zoom=`)
/// - Android: https://developer.android.com/guide/components/google-maps-intents
///   (`geo:lat,lon?z=&q=`)
/// - Yandex: resmî belgeyle doğrulanamadı; cihazda denenecek.
library;

enum MapApp { apple, google, yandex }

typedef LatLon = ({double lat, double lon});

/// Aramanın açılacağı yakınlık: yaklaşık 2–3 km'lik alan.
const int _zoom = 14;
const String _appleSpan = '0.03,0.03';

/// [query]'yi [center] çevresinde arayan bağlantı. [center] yoksa sorgu tek
/// başına gönderilir (çağıran konum adını sorguya ekler). Android'de uygulama
/// seçimini sistem yaptığı için [app] yok sayılır.
Uri mosqueSearchUri({
  required MapApp app,
  required String query,
  LatLon? center,
  required bool android,
  required bool appleUnified,
}) {
  final q = Uri.encodeComponent(query);
  if (android) {
    return Uri.parse(
      center == null
          ? 'geo:0,0?q=$q'
          : 'geo:${_c(center.lat)},${_c(center.lon)}?z=$_zoom&q=$q',
    );
  }
  final at = center == null ? null : '${_c(center.lat)},${_c(center.lon)}';
  return Uri.parse(switch (app) {
    MapApp.apple when appleUnified =>
      at == null
          ? 'https://maps.apple.com/search?query=$q'
          : 'https://maps.apple.com/search?query=$q&center=$at&span=$_appleSpan',
    MapApp.apple =>
      at == null
          ? 'https://maps.apple.com/?q=$q'
          : 'https://maps.apple.com/?q=$q&sll=$at&z=$_zoom',
    MapApp.google =>
      at == null
          ? 'comgooglemaps://?q=$q'
          : 'comgooglemaps://?q=$q&center=$at&zoom=$_zoom',
    MapApp.yandex =>
      center == null
          ? 'yandexmaps://maps.yandex.com/?text=$q'
          : 'yandexmaps://maps.yandex.com/?text=$q'
                '&ll=${_c(center.lon)},${_c(center.lat)}&z=$_zoom',
  });
}

/// iOS sürüm dizgisinden (`Platform.operatingSystemVersion`, ör. "18.4" ya da
/// "Version 18.3.1 (Build 22D72)") birleşik Apple Haritalar bağlantılarının
/// (18.4+) desteklenip desteklenmediği. Okunamayan sürüm → `false`.
bool appleUnifiedMapsSupported(String operatingSystemVersion) {
  final match = RegExp(r'(\d+)(?:\.(\d+))?').firstMatch(operatingSystemVersion);
  if (match == null) return false;
  final major = int.parse(match.group(1)!);
  final minor = int.tryParse(match.group(2) ?? '') ?? 0;
  return major > 18 || (major == 18 && minor >= 4);
}

/// Koordinatı en çok 6 ondalıkla, sondaki sıfırları atarak yazar ("41.0").
String _c(double value) {
  var s = value.toStringAsFixed(6);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  return s.endsWith('.') ? '${s}0' : s;
}
