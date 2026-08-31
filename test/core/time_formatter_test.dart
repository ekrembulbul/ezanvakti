import 'package:ezanvakti/core/utils/time_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final evening = DateTime(2026, 8, 31, 19, 5);
  final morning = DateTime(2026, 8, 31, 9, 7);

  test('h24 her zaman 24 saat basar', () {
    expect(
      TimeFormatter.format(evening, TimeFormatPreference.h24, systemUses24h: false),
      '19:05',
    );
    expect(
      TimeFormatter.format(morning, TimeFormatPreference.h24, systemUses24h: false),
      '09:07',
    );
  });

  test('h12 ogleden sonra PM yazar, basta sifir yok', () {
    expect(
      TimeFormatter.format(evening, TimeFormatPreference.h12, systemUses24h: true),
      '7:05 PM',
    );
    expect(
      TimeFormatter.format(morning, TimeFormatPreference.h12, systemUses24h: true),
      '9:07 AM',
    );
  });

  test('system tercihi cihaz ayarina uyar', () {
    expect(
      TimeFormatter.format(evening, TimeFormatPreference.system, systemUses24h: true),
      '19:05',
    );
    expect(
      TimeFormatter.format(evening, TimeFormatPreference.system, systemUses24h: false),
      '7:05 PM',
    );
  });

  test('saat/dakika ciftinden de bicimlendirir', () {
    expect(
      TimeFormatter.formatHourMinute(19, 5, TimeFormatPreference.h24, systemUses24h: true),
      '19:05',
    );
    expect(
      TimeFormatter.formatHourMinute(0, 30, TimeFormatPreference.h12, systemUses24h: true),
      '12:30 AM',
    );
  });

  test('depolama etiketleri kararli', () {
    for (final pref in TimeFormatPreference.values) {
      expect(TimeFormatPreference.fromStorage(pref.storageValue), pref);
    }
    expect(TimeFormatPreference.fromStorage('bilinmeyen'), TimeFormatPreference.system);
  });
}
