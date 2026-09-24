import 'package:ezanvakti/core/exceptions/parse_exception.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sağlayıcıya özgü ayrıştırma senaryoları `diyanet_provider_test.dart`'ta;
/// burada yalnız `ParseException` sözleşmesi doğrulanır.
void main() {
  group('Parse Error Handling - Storage', () {
    test('ParseException contains original error', () {
      final exception = ParseException(
        message: 'Test parse error',
        originalError: FormatException('Invalid format'),
        context: 'Test context',
      );

      expect(exception.message, equals('Test parse error'));
      expect(exception.originalError, isA<FormatException>());
      expect(exception.context, equals('Test context'));
    });

    test('ParseException toString includes all information', () {
      final exception = ParseException(
        message: 'Test error',
        originalError: 'Original',
        context: 'TestContext',
      );

      final stringValue = exception.toString();
      expect(stringValue, contains('Test error'));
      expect(stringValue, contains('TestContext'));
      expect(stringValue, contains('Original'));
    });

    test('getUserMessage kararli bir teshis anahtari doner', () {
      final exception = ParseException(message: 'Any technical message');

      final userMessage = exception.getUserMessage();
      expect(userMessage, isA<String>());
      expect(userMessage.length, greaterThan(0));
      expect(userMessage, 'parse_format_changed');
    });
  });
}
