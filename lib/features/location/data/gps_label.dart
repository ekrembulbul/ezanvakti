import 'package:geocoding/geocoding.dart';

/// Reverse-geocode sonucundan (Placemark) kullanıcıya gösterilecek il/ilçe
/// etiketini çıkarır. Namaz vakti ham koordinattan hesaplandığı için bu yalnızca
/// görünen etikettir; alanlar boşsa ülke veya genel bir etikete düşülür.
({String province, String district}) resolveGpsLabel(Placemark placemark) {
  final province = (placemark.administrativeArea ?? '').trim();
  final country = (placemark.country ?? '').trim();
  final district =
      (placemark.subAdministrativeArea ??
              placemark.locality ??
              placemark.subLocality ??
              '')
          .trim();

  final resolvedProvince = province.isNotEmpty
      ? province
      : (country.isNotEmpty ? country : 'GPS Konumu');
  final resolvedDistrict = district.isNotEmpty ? district : resolvedProvince;

  return (province: resolvedProvince, district: resolvedDistrict);
}
