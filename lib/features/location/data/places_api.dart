import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/vakit_api_config.dart';
import '../../../core/exceptions/api_exception.dart';
import '../../../core/exceptions/parse_exception.dart';
import '../../../core/models/location.dart';
import '../../../core/utils/app_logger.dart';

/// Sunucu koordinatın yakınında Diyanet ilçesi bulamadı (Türkiye dışı).
class NoCoverageException implements Exception {
  @override
  String toString() =>
      'NoCoverageException: no Diyanet district near coordinates';
}

/// Sunucu ilçe listesini henüz senkronlamadı (503 NOT_READY); kısa süre sonra dene.
class PlacesNotReadyException implements Exception {
  @override
  String toString() => 'PlacesNotReadyException: place list not ready';
}

/// `/v1/places/*` sonuç satırı; adlar ekranda gösterilecek yazımdadır.
class PlaceMatch {
  final int id;
  final String name;
  final String stateName;
  final String displayName;
  final int stateId;
  final int countryId;
  final bool isCentre;
  final double? latitude;
  final double? longitude;
  final double? qiblaAngle;
  final String? matchedAlias;

  const PlaceMatch({
    required this.id,
    required this.name,
    required this.stateName,
    required this.displayName,
    required this.stateId,
    required this.countryId,
    required this.isCentre,
    this.latitude,
    this.longitude,
    this.qiblaAngle,
    this.matchedAlias,
  });

  factory PlaceMatch.fromJson(Map<String, dynamic> json) {
    return PlaceMatch(
      id: json['id'] as int,
      name: json['name'] as String,
      stateName: json['stateName'] as String,
      displayName: json['displayName'] as String,
      stateId: json['stateId'] as int,
      countryId: json['countryId'] as int,
      isCentre: json['isCentre'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      qiblaAngle: (json['qiblaAngle'] as num?)?.toDouble(),
      matchedAlias: json['matchedAlias'] as String?,
    );
  }

  /// Manuel seçimde koordinat ilçe merkezidir; GPS'te çağıran cihaz
  /// koordinatını ve sabit `gps` kimliğini verir.
  Location toLocation({
    required LocationType type,
    String? id,
    double? latitude,
    double? longitude,
  }) {
    final cityId = this.id; // parametre `id` alanı gölgeliyor
    return Location(
      id: id ?? 'diyanet-$cityId',
      province: stateName,
      district: name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type,
      cityId: cityId,
      stateId: stateId,
      countryId: countryId,
      displayLabel: displayName,
    );
  }
}

class ResolveResult {
  final PlaceMatch city;
  final double distanceKm;
  const ResolveResult({required this.city, required this.distanceKm});
}

/// vakit-api yer uçları: metinden ilçe arama ve koordinattan en yakın ilçe.
class PlacesApi {
  final http.Client client;
  final String baseUrl;
  static const Duration _timeout = Duration(seconds: 15);

  PlacesApi({required this.client, this.baseUrl = VakitApiConfig.baseUrl});

  Future<List<PlaceMatch>> search(String query, {int limit = 10}) async {
    final uri = Uri.parse(
      '$baseUrl/v1/places/search',
    ).replace(queryParameters: {'q': query, 'limit': '$limit'});
    final body = await _get(uri);
    final results = body['results'];
    if (results is! List) {
      throw ParseException(
        message: 'search response has no results list',
        context: 'PlacesApi.search',
      );
    }
    return results
        .map((e) => PlaceMatch.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ResolveResult> resolve({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/v1/places/resolve',
    ).replace(queryParameters: {'lat': '$latitude', 'lon': '$longitude'});
    final body = await _get(uri);
    final city = body['city'];
    if (city is! Map<String, dynamic>) {
      throw ParseException(
        message: 'resolve response has no city',
        context: 'PlacesApi.resolve',
      );
    }
    return ResolveResult(
      city: PlaceMatch.fromJson(city),
      distanceKm: (body['distanceKm'] as num?)?.toDouble() ?? 0,
    );
  }

  /// 200 → JSON nesnesi. 404 NO_COVERAGE ve 503 ayrı hatalar; diğer durumlar
  /// [ApiException]. Gövde JSON değilse [ParseException].
  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await client.get(uri).timeout(_timeout);
    if (response.statusCode == 503) throw PlacesNotReadyException();
    if (response.statusCode == 404 &&
        _errorCode(response.body) == 'NO_COVERAGE') {
      throw NoCoverageException();
    }
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, context: 'GET ${uri.path}');
    }
    try {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('not an object');
      }
      return decoded;
    } on FormatException catch (e, stackTrace) {
      AppLogger().parseError(
        context: 'PlacesApi._get',
        error: e,
        stackTrace: stackTrace,
        additionalData: {'path': uri.path},
      );
      throw ParseException(
        message: 'places response is not JSON',
        originalError: e,
        stackTrace: stackTrace,
        context: 'PlacesApi._get',
      );
    }
  }

  static String? _errorCode(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map && decoded['error'] is Map) {
        return (decoded['error'] as Map)['code'] as String?;
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
