import 'package:geocoding/geocoding.dart';

/// Reverse-geocode sonucundan (Placemark) kullanıcıya gösterilecek il/ilçe
/// etiketini çıkarır. Namaz vakti ham koordinattan hesaplandığı için bu yalnızca
/// görünen etikettir; alanlar boşsa ülke veya genel bir etikete düşülür.
/// [fallbackLabel] hem il hem ülke boşsa kullanılır; çeviri çağırandan gelir.
({String province, String district}) resolveGpsLabel(
  Placemark placemark, {
  required String fallbackLabel,
}) {
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
      : (country.isNotEmpty ? country : fallbackLabel);
  final resolvedDistrict = district.isNotEmpty ? district : resolvedProvince;

  return (province: resolvedProvince, district: resolvedDistrict);
}
