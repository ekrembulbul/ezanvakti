class ParseException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final String? context;

  ParseException({
    required this.message,
    this.originalError,
    this.stackTrace,
    this.context,
  });

  @override
  String toString() {
    final buffer = StringBuffer('ParseException: $message');
    if (context != null) {
      buffer.write('\nContext: $context');
    }
    if (originalError != null) {
      buffer.write('\nOriginal error: $originalError');
    }
    return buffer.toString();
  }

  String getUserMessage() {
    return 'Veri formatı değişmiş olabilir. Lütfen uygulamayı güncellemeyi deneyin.';
  }
}
