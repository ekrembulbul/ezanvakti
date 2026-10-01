import '../../core/interfaces/local_storage.dart';
import '../../core/utils/app_logger.dart';
import '../../features/mosques/domain/map_links.dart';

/// Yakındaki camiler için harita uygulamasını seçer ve açar. Kendi cami
/// verimiz yok; arama seçilen koordinatın çevresinde harita uygulamasında
/// yapılır. Platform erişimi ([canOpen], [open]) testte değiştirilebilir.
class NearbyMosquesLauncher {
  final LocalStorage storage;
  final bool isIOS;
  final String osVersion;
  final Future<bool> Function(Uri) canOpen;
  final Future<bool> Function(Uri) open;

  static const String _appKey = 'maps_app';

  NearbyMosquesLauncher({
    required this.storage,
    required this.isIOS,
    required this.osVersion,
    required this.canOpen,
    required this.open,
  });

  /// iOS'ta yüklü harita uygulamaları (Apple her zaman ilk). Android'de seçimi
  /// sistem yaptığı için boş.
  Future<List<MapApp>> installedApps() async {
    if (!isIOS) return const [];
    return [
      MapApp.apple,
      if (await _installed('comgooglemaps://')) MapApp.google,
      if (await _installed('yandexmaps://')) MapApp.yandex,
    ];
  }

  /// Hatırlanan uygulama; artık yüklü değilse `null` (yeniden sorulur).
  Future<MapApp?> savedApp() async {
    final app = MapApp.values.asNameMap()[await storage.getSetting(_appKey)];
    if (app == null) return null;
    return (await installedApps()).contains(app) ? app : null;
  }

  /// `null` seçimi temizler ("her seferinde sor").
  Future<void> saveApp(MapApp? app) =>
      storage.setSetting(_appKey, app?.name ?? '');

  /// [query]'yi [center] çevresinde açar; açılamazsa `false`.
  Future<bool> launch({
    required MapApp app,
    required String query,
    LatLon? center,
  }) async {
    final uri = mosqueSearchUri(
      app: app,
      query: query,
      center: center,
      android: !isIOS,
      appleUnified: appleUnifiedMapsSupported(osVersion),
    );
    try {
      return await open(uri);
    } catch (e, s) {
      AppLogger().warning('Maps app launch failed: ${uri.scheme}', e, s);
      return false;
    }
  }

  Future<bool> _installed(String url) async {
    try {
      return await canOpen(Uri.parse(url));
    } catch (e, s) {
      AppLogger().warning('Maps app check failed: $url', e, s);
      return false;
    }
  }
}
