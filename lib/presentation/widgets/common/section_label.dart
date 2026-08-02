import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// `SIRADAKİ`, `YARIN`, `3 ALARM` gibi bölüm başlıkları.
///
/// Metni büyük harfe kendisi çevirir — çağıran yerde `'SIRADAKİ'` yazmak
/// yerine `'Sıradaki'` yazılır, böylece Türkçe `i → İ` dönüşümü tek yerde
/// doğru yapılır.
class SectionLabel extends StatelessWidget {
  final String text;

  /// Sağa yaslanan ikincil eylem, örn. "Tümü" ya da "Takvim".
  final Widget? trailing;

  const SectionLabel(this.text, {super.key, this.trailing});

  /// Dart'ın `toUpperCase()`'i noktalı `i`'yi `I` yapar; Türkçe'de doğrusu
  /// `İ`'dir. Noktasız `ı` zaten `I` olur.
  static String toTurkishUpperCase(String value) =>
      value.replaceAll('i', 'İ').toUpperCase();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          toTurkishUpperCase(text),
          style: AppTypography.sectionLabel.copyWith(
            color: tokens.textTertiary,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}
