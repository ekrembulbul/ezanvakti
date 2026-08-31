import 'notification_setting.dart' show PrayerType;

/// Altı vakitten hesaplanan hatırlatma noktaları.
///
/// Bunlar `PrayerType`e eklenmez: widget snapshot'ı, alarm çıpası ve vakit
/// tablosu altı vakit üzerine kurulu. Türetilmiş noktalar yalnızca bildirim
/// tarafında yaşar ve her biri bir vakte çıpalıdır.
enum DerivedTimeKind {
  /// Kerahat-1 biter, işrak/duha vakti başlar (güneş + N dk).
  ishraq,

  /// Kerahat-2: zeval/istiva vakti (öğle − N dk).
  istiwa,

  /// Kerahat-3: akşam öncesi (akşam − N dk).
  preMaghrib,

  /// Şer'i gece yarısı (akşam + gecenin yarısı).
  midnight,

  /// Gecenin son üçte biri — teheccüd penceresi başlangıcı.
  lastThird,
}

extension DerivedTimeKindX on DerivedTimeKind {
  /// Hesabın dayandığı vakit. Bildirim satırı bu vakti `prayerType` olarak
  /// taşır; sıralama ve gruplama buna göre yapılır.
  PrayerType get anchor => switch (this) {
    DerivedTimeKind.ishraq => PrayerType.sunrise,
    DerivedTimeKind.istiwa => PrayerType.dhuhr,
    DerivedTimeKind.preMaghrib => PrayerType.maghrib,
    DerivedTimeKind.midnight => PrayerType.maghrib,
    DerivedTimeKind.lastThird => PrayerType.maghrib,
  };

  String get label => switch (this) {
    DerivedTimeKind.ishraq => 'İşrak',
    DerivedTimeKind.istiwa => 'Kerahat (zeval)',
    DerivedTimeKind.preMaghrib => 'Kerahat (akşam öncesi)',
    DerivedTimeKind.midnight => 'Gece yarısı',
    DerivedTimeKind.lastThird => 'Gecenin son üçte biri',
  };

  String get description => switch (this) {
    DerivedTimeKind.ishraq => 'Güneşten sonra kerahat biter',
    DerivedTimeKind.istiwa => 'Öğleden önceki kerahat başlar',
    DerivedTimeKind.preMaghrib => 'Akşamdan önceki kerahat başlar',
    DerivedTimeKind.midnight => 'Şer\'i gecenin ortası',
    DerivedTimeKind.lastThird => 'Teheccüd vakti başlar',
  };

  /// Depolamada kullanılan kararlı değer; enum adı değişse de kayıt bozulmaz.
  String get storageValue => switch (this) {
    DerivedTimeKind.ishraq => 'ishraq',
    DerivedTimeKind.istiwa => 'istiwa',
    DerivedTimeKind.preMaghrib => 'pre_maghrib',
    DerivedTimeKind.midnight => 'midnight',
    DerivedTimeKind.lastThird => 'last_third',
  };

  /// Hesabı ertesi günün imsakını gerektiriyor mu.
  bool get needsNextDay =>
      this == DerivedTimeKind.midnight || this == DerivedTimeKind.lastThird;

  static DerivedTimeKind? fromStorage(String? value) {
    if (value == null) return null;
    for (final kind in DerivedTimeKind.values) {
      if (kind.storageValue == value) return kind;
    }
    return null;
  }
}

/// Türetilmiş vakitlerin ayarlanabilir sabitleri.
///
/// Takvimler farklı kabuller kullanıyor (kerahat için 40–50 dk gibi); kullanıcı
/// elindeki takvime uydurabilsin diye sabitler tek yerde toplandı.
class DerivedTimeSettings {
  final int ishraqMinutes;
  final int istiwaMinutes;
  final int preMaghribMinutes;

  const DerivedTimeSettings({
    this.ishraqMinutes = 45,
    this.istiwaMinutes = 10,
    this.preMaghribMinutes = 45,
  });

  static const DerivedTimeSettings defaults = DerivedTimeSettings();
}
