import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/vakit_api_config.dart';
import '../../../core/exceptions/api_exception.dart';
import '../../../core/exceptions/parse_exception.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/sermon.dart';

/// vakit-api `/v1/sermons` ve `/v1/sermons/{id}` uçları.
class SermonsApi {
  final http.Client client;
  final String baseUrl;
  static const Duration _timeout = Duration(seconds: 15);

  SermonsApi({required this.client, this.baseUrl = VakitApiConfig.baseUrl});

  /// Son 20 hutbe, tarih azalan.
  Future<List<SermonSummary>> fetchIndex() async {
    final body = await _get(Uri.parse('$baseUrl/v1/sermons'));
    final sermons = body['sermons'];
    if (sermons is! List) {
      throw ParseException(
        message: 'sermons list missing',
        context: 'SermonsApi.fetchIndex',
      );
    }
    return [
      for (final s in sermons)
        SermonSummary.fromJson(s as Map<String, dynamic>),
    ];
  }

  Future<SermonText> fetchText(String id) async {
    final body = await _get(
      Uri.parse('$baseUrl/v1/sermons/${Uri.encodeComponent(id)}'),
    );
    return SermonText.fromJson(body);
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await client.get(uri).timeout(_timeout);
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
        context: 'SermonsApi._get',
        error: e,
        stackTrace: stackTrace,
        additionalData: {'path': uri.path},
      );
      throw ParseException(
        message: 'sermons response is not JSON',
        originalError: e,
        stackTrace: stackTrace,
        context: 'SermonsApi._get',
      );
    }
  }
}
