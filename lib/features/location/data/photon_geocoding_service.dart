import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/utils/app_logger.dart';
import 'place_suggestion.dart';

/// Photon (komoot/OpenStreetMap) tabanlı adres arama servisi.
///
/// Search-as-you-type için tasarlanmıştır; global kapsamlıdır. Verilen
/// koordinat bias'ı sonuçları kullanıcının yakınına önceler ama global
/// sonuçları engellemez. Veri © OpenStreetMap katkıcıları (ODbL).
class PhotonGeocodingService {
  final http.Client httpClient;

  static const String _baseUrl = 'https://photon.komoot.io/api';
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const int _defaultLimit = 8;
  static const int _minQueryLength = 2;

  // Photon, Dart http paketinin varsayılan "Dart/x (dart:io)" User-Agent'ını
  // 403 ile engelliyor. Uygulamayı tanımlayan bir UA göndermek hem bu engeli
  // aşar hem de OSM/Photon fair-use beklentisine uyar.
  static const Map<String, String> _headers = {
    'User-Agent': 'EzanVakti/1.0 (Flutter; namaz vakti uygulamasi)',
  };

  PhotonGeocodingService({http.Client? httpClient})
    : httpClient = httpClient ?? http.Client();

  /// [query] için yer önerileri döner. Ağ/parse hatalarında boş liste döner
  /// (arama kutusu çökmemeli); hatalar loglanır, sessizce yutulmaz.
  Future<List<PlaceSuggestion>> search(
    String query, {
    double? biasLatitude,
    double? biasLongitude,
    String? language,
    int limit = _defaultLimit,
  }) async {
    final logger = AppLogger();
    final trimmed = query.trim();
    if (trimmed.length < _minQueryLength) return const [];

    final params = <String, String>{'q': trimmed, 'limit': '$limit'};
    // Photon public instance yalnızca default/de/en/fr destekler; 'tr' 400 verir.
    // Belirtilmezse "default" (yerel ad) kullanılır — Türkçe yerler için doğru.
    if (language != null) params['lang'] = language;
    if (biasLatitude != null && biasLongitude != null) {
      params['lat'] = '$biasLatitude';
      params['lon'] = '$biasLongitude';
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);

    try {
      final response = await httpClient
          .get(uri, headers: _headers)
          .timeout(_requestTimeout);
      if (response.statusCode != 200) {
        logger.warning('Photon search returned HTTP ${response.statusCode}');
        return const [];
      }
      // Türkçe karakterlerin bozulmaması için yanıtı açıkça UTF-8 çözeriz;
      // sunucu charset header'ı atlasa bile (http aksi halde latin1'e düşer).
      return _parseResponse(utf8.decode(response.bodyBytes));
    } catch (e, stackTrace) {
      // Ağ/timeout/parse: arama kutusu graceful degrade etsin, boş dönsün.
      logger.warning('Photon search failed for query "$trimmed"', e);
      logger.debug('Photon search stack trace: $stackTrace');
      return const [];
    }
  }

  List<PlaceSuggestion> _parseResponse(String body) {
    final decoded = json.decode(body) as Map<String, dynamic>;
    final features = decoded['features'] as List<dynamic>? ?? const [];

    final suggestions = <PlaceSuggestion>[];
    for (final feature in features) {
      if (feature is! Map<String, dynamic>) continue;
      final suggestion = PlaceSuggestion.fromPhotonFeature(feature);
      if (suggestion != null) suggestions.add(suggestion);
    }
    return suggestions;
  }
}
