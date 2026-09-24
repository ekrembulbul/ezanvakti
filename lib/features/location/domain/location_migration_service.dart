import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/location.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/turkish_fold.dart';
import '../data/places_api.dart';

/// Bir kayıtlı konum için migrasyon sonucu.
enum MigrationDecision {
  /// Güvenli eşleşme bulundu ve yazıldı.
  mapped,

  /// Sunucu sonuç verdi ama güvenle seçilemedi; kullanıcı [MigrationItem.suggestions]
  /// arasından seçer.
  ambiguous,

  /// Sunucuda karşılığı yok (Türkiye dışı ya da tanınmayan ad).
  unsupported,
}

class MigrationItem {
  /// [MigrationDecision.mapped] ise eşlenmiş yeni konum; diğer durumlarda
  /// dokunulmamış eski kayıt.
  final Location location;
  final MigrationDecision decision;
  final List<PlaceMatch> suggestions;

  const MigrationItem({
    required this.location,
    required this.decision,
    this.suggestions = const [],
  });
}

class MigrationReport {
  final List<MigrationItem> items;

  const MigrationReport(this.items);

  bool get needsUserInput =>
      items.any((item) => item.decision != MigrationDecision.mapped);

  int get mappedCount =>
      items.where((item) => item.decision == MigrationDecision.mapped).length;
}

/// Eski (koordinat tabanlı) konum kayıtlarını Diyanet ilçesine bağlar.
///
/// Güncelleme sonrası ilk açılışta çalışır. Zaten eşlenmiş konumlar rapora
/// girmez. Güvenli eşleşmeler sessizce yazılır ve vakit önbelleği temizlenir;
/// belirsiz ve desteklenmeyenler karar için ekrana bırakılır (Plan B2).
///
/// Ağ/sunucu hatası (`ApiException`, `PlacesNotReadyException`,
/// `SocketException`, `TimeoutException`) dışarı çıkar: o ana kadar eşlenen
/// konumlar kalır, çağıran bir sonraki açılışa erteler. Hata "belirsiz" gibi
/// raporlanmaz; yoksa geçici bir kesinti kullanıcıya yanlış seçim yaptırır.
class LocationMigrationService {
  final LocalStorage storage;
  final PlacesApi api;
  final Future<void> Function(String locationId) clearPrayerCache;

  static const int _suggestionLimit = 5;

  LocationMigrationService({
    required this.storage,
    required this.api,
    required this.clearPrayerCache,
  });

  Future<MigrationReport> run() async {
    final logger = AppLogger();
    final locations = await storage.getSavedLocations();
    final active = await storage.getActiveLocation();
    final items = <MigrationItem>[];

    for (final location in locations) {
      if (location.isMapped) continue;

      final item = await _migrate(location);
      items.add(item);
      if (item.decision != MigrationDecision.mapped) continue;

      await storage.updateLocation(item.location);
      await clearPrayerCache(item.location.id);
      if (active != null && active.id == item.location.id) {
        await storage.saveActiveLocation(item.location);
      }
      logger.info(
        'Location migrated: ${item.location.id} -> cityId ${item.location.cityId}',
      );
    }

    return MigrationReport(items);
  }

  Future<MigrationItem> _migrate(Location location) async {
    final latitude = location.latitude;
    final longitude = location.longitude;
    if (location.type == LocationType.gps &&
        latitude != null &&
        longitude != null) {
      return _migrateByCoordinates(location, latitude, longitude);
    }
    return _migrateByName(location);
  }

  /// GPS kaydı: cihaz koordinatı ve `gps` kimliği korunur, ilçe sunucudan.
  Future<MigrationItem> _migrateByCoordinates(
    Location location,
    double latitude,
    double longitude,
  ) async {
    try {
      final result = await api.resolve(
        latitude: latitude,
        longitude: longitude,
      );
      final mapped = result.city
          .toLocation(
            type: LocationType.gps,
            id: location.id,
            latitude: latitude,
            longitude: longitude,
          )
          .copyWith(customName: location.customName);
      return MigrationItem(
        location: mapped,
        decision: MigrationDecision.mapped,
      );
    } on NoCoverageException {
      return MigrationItem(
        location: location,
        decision: MigrationDecision.unsupported,
      );
    }
  }

  /// Manuel kayıt (ya da koordinatsız GPS kaydı): il/ilçe adıyla aranır.
  /// Yalnız ilk sonuç güvenliyse otomatik eşlenir; koordinat ilçe merkezi
  /// olur, kimlik ve özel ad korunur.
  Future<MigrationItem> _migrateByName(Location location) async {
    final results = await api.search(
      '${location.district} ${location.province}',
      limit: _suggestionLimit,
    );
    if (results.isEmpty) {
      return MigrationItem(
        location: location,
        decision: MigrationDecision.unsupported,
      );
    }

    final first = results.first;
    if (!isConfident(first, location)) {
      return MigrationItem(
        location: location,
        decision: MigrationDecision.ambiguous,
        suggestions: results,
      );
    }

    final mapped = first
        .toLocation(type: location.type, id: location.id)
        .copyWith(customName: location.customName);
    return MigrationItem(location: mapped, decision: MigrationDecision.mapped);
  }

  /// Eşleşme güvenli mi? İl adı her durumda tutmalı; ayrıca ilçe adı aynı
  /// anahtara katlanıyorsa, il merkezinde ilçe = il ise ya da sunucunun
  /// bildirdiği eşanlam (Kadıköy → İstanbul) ilçeyle tutuyorsa güvenlidir.
  static bool isConfident(PlaceMatch match, Location location) {
    final district = foldTR(location.district);
    final province = foldTR(location.province);
    if (foldTR(match.stateName) != province) return false;
    if (foldTR(match.name) == district) return true;
    if (match.isCentre && district == province) return true;
    final alias = match.matchedAlias;
    return alias != null && foldTR(alias) == district;
  }
}
