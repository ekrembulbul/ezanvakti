import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Application-wide structured logger.
///
/// Behaviour by build mode:
/// - **Debug:** all levels are emitted ([debug] and above).
/// - **Release:** only [warning] and [error] are emitted, so production logs
///   stay quiet and internal state is not leaked.
///
/// Never pass secrets or personal data (tokens, passwords, exact GPS
/// coordinates) to these methods.
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();

  factory AppLogger() => _instance;

  late final Logger _logger;

  AppLogger._internal() {
    _logger = Logger(
      level: kReleaseMode ? Level.warning : Level.debug,
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 6,
        lineLength: 100,
        colors: true,
        printEmojis: false,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
    );
  }

  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  void info(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  void parseError({
    required String context,
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalData,
  }) {
    final buffer = StringBuffer('Parse error in $context');
    if (additionalData != null && additionalData.isNotEmpty) {
      buffer.write('\nAdditional data: $additionalData');
    }
    _logger.e(buffer.toString(), error: error, stackTrace: stackTrace);
  }
}
