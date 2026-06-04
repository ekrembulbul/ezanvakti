import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/models/regional_defaults.dart';

void main() {
  group('RegionalDefaults.settingsForCountryCode', () {
    test('Turkey maps to Diyanet with standard Asr', () {
      final settings = RegionalDefaults.settingsForCountryCode('TR');

      expect(settings, isNotNull);
      expect(settings!.method, equals(13));
      expect(settings.school, equals(0));
    });

    test('North America maps to ISNA', () {
      expect(RegionalDefaults.settingsForCountryCode('US')!.method, equals(2));
      expect(RegionalDefaults.settingsForCountryCode('CA')!.method, equals(2));
    });

    test('South Asia maps to Karachi with Hanafi Asr', () {
      final settings = RegionalDefaults.settingsForCountryCode('PK');

      expect(settings!.method, equals(5));
      expect(settings.school, equals(1));
    });

    test('Country code is case-insensitive', () {
      expect(RegionalDefaults.settingsForCountryCode('tr')!.method, equals(13));
    });

    test('Unknown country returns null (keep existing default)', () {
      expect(RegionalDefaults.settingsForCountryCode('ZZ'), isNull);
    });

    test('Null or empty country returns null', () {
      expect(RegionalDefaults.settingsForCountryCode(null), isNull);
      expect(RegionalDefaults.settingsForCountryCode(''), isNull);
    });
  });
}
