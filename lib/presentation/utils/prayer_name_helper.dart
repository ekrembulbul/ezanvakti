import '../../core/models/notification_setting.dart' show PrayerType;

/// Vakitlerin sıralama yardımcıları.
///
/// **Ad döndüren metotlar kaldırıldı**: vakit adları artık
/// `context.l10n.prayerName(type)` ile çeviriden geliyor. Türkçe ad döndüren
/// eski API, çeviri gelince adın kimlik gibi kullanıldığı yerlerde
/// (ikon seçimi, palet hesabı) sessiz hatalara yol açıyordu.
class PrayerNameHelper {
  const PrayerNameHelper._();

  static List<PrayerType> getAllPrayerTypes() => PrayerType.values;

  /// Gün içindeki sıra; enum zaten bu sırada tanımlı.
  static int getPrayerOrder(PrayerType type) => type.index;
}
