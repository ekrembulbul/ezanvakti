import 'calculation_params.dart';
import 'calculation_settings.dart';

/// Ülke koduna göre uygun varsayılan hesaplama ayarını üretir.
///
/// Kullanıcı ilk konumunu seçtiğinde, bulunduğu ülkeye uygun bir başlangıç
/// ayarı atamak için kullanılır. Kullanıcı sonradan Ayarlar > Hesaplama'dan
/// değiştirebilir. Eşleme yalnızca Aladhan'ın o ülke için resmi otoritesinin
/// bulunduğu (veya yerleşik bölgesel pratiğin olduğu) durumları kapsar.
class RegionalDefaults {
  const RegionalDefaults._();

  /// ISO 3166-1 alpha-2 ülke kodu → Aladhan hesaplama yöntemi (method) id.
  static const Map<String, int> _methodByCountry = {
    'TR': 13, // Diyanet İşleri Başkanlığı
    'EG': 3, // Egyptian General Authority of Survey
    'SA': 4, // Umm Al-Qura, Mekke
    'PK': 5, 'IN': 5, 'BD': 5, 'AF': 5, // Karachi (Güney Asya, Hanefi)
    'US': 2, 'CA': 2, // ISNA (Kuzey Amerika)
    'KW': 9, // Kuveyt
    'QA': 10, // Katar
    'SG': 11, // Singapur
    'FR': 12, // Fransa
    'RU': 14, // Rusya
    'AE': 16, // Dubai (BAE)
    'MY': 17, // JAKIM (Malezya)
    'TN': 18, // Tunus
    'DZ': 19, // Cezayir
    'ID': 20, // Endonezya
    'MA': 21, // Fas
    'PT': 22, // Portekiz
  };

  /// Verilen ülke koduna (ISO alpha-2) uygun varsayılan hesaplama ayarını döner.
  /// Eşleşme yoksa `null` döner; çağıran taraf mevcut varsayılanı korur.
  static CalculationSettings? settingsForCountryCode(String? isoCode) {
    if (isoCode == null || isoCode.isEmpty) return null;
    final method = _methodByCountry[isoCode.toUpperCase()];
    if (method == null) return null;
    return CalculationSettings(
      method: method,
      school: CalculationDefaults.schoolForMethod(method),
    );
  }
}
