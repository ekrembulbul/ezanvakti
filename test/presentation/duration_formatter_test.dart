import 'package:ezanvakti/core/utils/duration_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/l10n_helper.dart';

void main() {
  test(
    'dakika, saat ve gün sınırlarında en büyük anlamlı birimi kullanır',
    () async {
      final l10n = await loadTestL10n();

      expect(formatCompactMinutes(59, l10n), '59 dk');
      expect(formatCompactMinutes(60, l10n), '1 sa');
      expect(formatCompactMinutes(61, l10n), '1 sa 1 dk');
      expect(formatCompactMinutes(1439, l10n), '23 sa 59 dk');
      expect(formatCompactMinutes(1440, l10n), '1 gün');
      expect(formatCompactMinutes(1565, l10n), '1 gün 2 sa 5 dk');
    },
  );

  test('bir dakikadan kısa kalan süreyi ayrı gösterir', () async {
    final l10n = await loadTestL10n();

    expect(formatCompactDuration(const Duration(seconds: 59), l10n), '<1dk');
    expect(formatCompactMinutes(0, l10n), '0 dk');
  });

  test(
    'dakika:saniye sayacı; saatten uzun süre saat ekler, geçmiş sıfırlanır',
    () {
      expect(
        formatMinutesSeconds(const Duration(minutes: 14, seconds: 32)),
        '14:32',
      );
      expect(formatMinutesSeconds(const Duration(minutes: 45)), '45:00');
      expect(formatMinutesSeconds(const Duration(seconds: 5)), '00:05');
      expect(formatMinutesSeconds(Duration.zero), '00:00');
      expect(formatMinutesSeconds(const Duration(seconds: -3)), '00:00');
      expect(
        formatMinutesSeconds(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    },
  );
}
