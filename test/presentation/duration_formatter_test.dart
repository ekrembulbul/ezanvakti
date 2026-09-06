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
}
