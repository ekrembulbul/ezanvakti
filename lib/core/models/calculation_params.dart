/// Aladhan namaz vakti hesaplama parametreleri.
///
/// Bir konum için hangi otoritenin (method) ve hangi İkindi mezhebinin (school)
/// kullanılacağını tanımlar. Resmi kaynak:
/// https://aladhan.com/calculation-methods
library;

/// Yeni bir konum için varsayılan hesaplama parametreleri.
///
/// Türkiye odaklı varsayılan: Diyanet + standart (Şafi) İkindi. Kullanıcı konum
/// başına değiştirebilir.
class CalculationDefaults {
  const CalculationDefaults._();

  /// Diyanet İşleri Başkanlığı (Aladhan method=13).
  static const int method = 13;

  /// Standart/Şafi İkindi (Aladhan school=0). Diyanet takvimi İkindi'yi
  /// **asr-ı evvel**'e göre (gölge = cisim boyu) hazırlar; bu Aladhan'da
  /// school=0'a karşılık gelir. Hanefi (asr-ı sani) school=1'dir.
  static const int school = 0;

  // Hanefi İkindi'nin (asr-ı sani) yerleşik bölgesel norm olduğu yöntemler.
  // Güney Asya (Pakistan/Hindistan/Bangladeş) için Karachi yöntemi (5).
  static const Set<int> _hanafiAsrMethods = {5};

  /// Seçilen yönteme göre bölgesel olarak uygun varsayılan İkindi mezhebini
  /// döner. Çoğu otorite (Diyanet dahil) standart/Şafi İkindi kullanır; yalnızca
  /// Hanefi İkindi'nin norm olduğu bölgelerde 1 (Hanefi) döner.
  static int schoolForMethod(int method) {
    return _hanafiAsrMethods.contains(method) ? 1 : 0;
  }
}

/// Aladhan hesaplama yöntemi: namaz açılarını belirleyen otorite.
class CalculationMethod {
  final int id;
  final String name;

  const CalculationMethod({required this.id, required this.name});
}

/// Aladhan'ın desteklediği hesaplama yöntemleri (id ve görünen ad).
///
/// id değerleri Aladhan API'sinin `method` parametresine birebir karşılık gelir.
class CalculationMethods {
  const CalculationMethods._();

  static const List<CalculationMethod> all = [
    CalculationMethod(id: 1, name: 'Muslim World League'),
    CalculationMethod(id: 2, name: 'Islamic Society of North America (ISNA)'),
    CalculationMethod(id: 3, name: 'Egyptian General Authority of Survey'),
    CalculationMethod(id: 4, name: 'Umm Al-Qura University, Mekke'),
    CalculationMethod(id: 5, name: 'University of Islamic Sciences, Karaçi'),
    CalculationMethod(id: 6, name: 'Institute of Geophysics, Tahran'),
    CalculationMethod(id: 7, name: 'Shia Ithna-Ashari, Leva Institute, Kum'),
    CalculationMethod(id: 8, name: 'Körfez Bölgesi'),
    CalculationMethod(id: 9, name: 'Kuveyt'),
    CalculationMethod(id: 10, name: 'Katar'),
    CalculationMethod(id: 11, name: 'Majlis Ugama Islam Singapura, Singapur'),
    CalculationMethod(
      id: 12,
      name: 'Union des Organisations Islamiques de France',
    ),
    CalculationMethod(id: 13, name: 'Diyanet İşleri Başkanlığı (Türkiye)'),
    CalculationMethod(id: 14, name: 'Rusya Müslümanları Dini İdaresi'),
    CalculationMethod(id: 15, name: 'Moonsighting Committee Worldwide'),
    CalculationMethod(id: 16, name: 'Dubai (BAE)'),
    CalculationMethod(id: 17, name: 'Jabatan Kemajuan Islam Malaysia (JAKIM)'),
    CalculationMethod(id: 18, name: 'Tunus'),
    CalculationMethod(id: 19, name: 'Cezayir'),
    CalculationMethod(id: 20, name: 'Endonezya Din İşleri Bakanlığı'),
    CalculationMethod(id: 21, name: 'Fas'),
    CalculationMethod(id: 22, name: 'Comunidade Islâmica de Lisboa (Portekiz)'),
  ];

  /// Verilen id'ye karşılık gelen yöntemi döner; bulunamazsa Diyanet'e düşer.
  static CalculationMethod byId(int id) {
    for (final method in all) {
      if (method.id == id) return method;
    }
    return all.firstWhere((m) => m.id == CalculationDefaults.method);
  }
}

/// İkindi (Asr) hesabı için fıkhi mezhep — Aladhan `school` parametresi.
enum AsrSchool {
  shafi(value: 0, label: 'Şafi (Standart)'),
  hanafi(value: 1, label: 'Hanefi');

  const AsrSchool({required this.value, required this.label});

  final int value;
  final String label;

  static AsrSchool fromValue(int value) {
    return values.firstWhere(
      (school) => school.value == value,
      orElse: () => hanafi,
    );
  }
}

/// Yüksek enlem bölgeleri için imsak/yatsı düzeltme yöntemi —
/// Aladhan `latitudeAdjustmentMethod` parametresi. `null` ise API varsayılanı.
enum LatitudeAdjustment {
  auto(value: null, label: 'Otomatik'),
  middleOfNight(value: 1, label: 'Gece ortası'),
  oneSeventh(value: 2, label: 'Gecenin yedide biri'),
  angleBased(value: 3, label: 'Açı tabanlı');

  const LatitudeAdjustment({required this.value, required this.label});

  final int? value;
  final String label;

  static LatitudeAdjustment fromValue(int? value) {
    return values.firstWhere(
      (adjustment) => adjustment.value == value,
      orElse: () => auto,
    );
  }
}
