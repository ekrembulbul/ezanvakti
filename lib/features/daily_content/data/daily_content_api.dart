import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/vakit_api_config.dart';
import '../../../core/exceptions/api_exception.dart';
import '../../../core/exceptions/parse_exception.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/daily_content.dart';

/// vakit-api `/v1/daily-content/{YYYY-MM-DD}` ucu.
class DailyContentApi {
  final http.Client client;
  final String baseUrl;
  static const Duration _timeout = Duration(seconds: 15);

  DailyContentApi({
    required this.client,
    this.baseUrl = VakitApiConfig.baseUrl,
  });

  /// [day]'in takvim gününün içeriği. 404 → `null` (sunucu henüz almadı);
  /// diğer durumlar [ApiException], biçimsiz gövde [ParseException].
  Future<DailyContent?> fetch(DateTime day) async {
    final date =
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse('$baseUrl/v1/daily-content/$date');
    final response = await client.get(uri).timeout(_timeout);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, context: 'GET ${uri.path}');
    }
    final Object? decoded;
    try {
      decoded = json.decode(utf8.decode(response.bodyBytes));
    } on FormatException catch (e, stackTrace) {
      AppLogger().parseError(
        context: 'DailyContentApi.fetch',
        error: e,
        stackTrace: stackTrace,
        additionalData: {'path': uri.path},
      );
      throw ParseException(
        message: 'daily content response is not JSON',
        originalError: e,
        stackTrace: stackTrace,
        context: 'DailyContentApi.fetch',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw ParseException(
        message: 'daily content response is not an object',
        context: 'DailyContentApi.fetch',
      );
    }
    return DailyContent.fromJson(decoded);
  }
}
