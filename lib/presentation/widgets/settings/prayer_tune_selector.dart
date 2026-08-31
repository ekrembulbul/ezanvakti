import 'package:flutter/material.dart';
import '../../../l10n/l10n_extensions.dart';

import '../../../core/models/notification_setting.dart' show PrayerType;
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// Vakit başına ± dakika düzeltmesi. Kullanıcı, hesaplanan vakitle elindeki
/// takvim arasındaki 1–2 dakikalık farkı buradan kapatır.
class PrayerTuneSelector extends StatelessWidget {
  /// Sıfır olan vakitler haritada bulunmayabilir; eksik değer 0 sayılır.
  final Map<PrayerType, int> tune;
  final ValueChanged<Map<PrayerType, int>> onChanged;

  /// Kaydırma sınırı: bunun ötesi düzeltme değil, yanlış yöntem seçimi
  /// demektir — kullanıcıyı hatalı ayara hapsetmemek için dar tutuluyor.
  static const int maxMinutes = 15;

  const PrayerTuneSelector({
    super.key,
    required this.tune,
    required this.onChanged,
  });

  void _bump(PrayerType type, int delta) {
    final current = tune[type] ?? 0;
    final next = (current + delta).clamp(-maxMinutes, maxMinutes);
    if (next == current) return;
    final updated = Map<PrayerType, int>.from(tune);
    if (next == 0) {
      updated.remove(type);
    } else {
      updated[type] = next;
    }
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.calcTuneHint,
          style: AppTypography.hint.copyWith(
            color: tokens.textTertiary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        for (final type in PrayerType.values) _row(context, type),
      ],
    );
  }

  Widget _row(BuildContext context, PrayerType type) {
    final tokens = context.tokens;
    final value = tune[type] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.prayerName(type),
              style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
            ),
          ),
          _stepButton(
            context,
            icon: Icons.remove_rounded,
            onTap: () => _bump(type, -1),
            enabled: value > -maxMinutes,
          ),
          SizedBox(
            width: 64,
            child: Text(
              value == 0
                  ? context.l10n.minutesShort(0)
                  : context.l10n.offsetMinutes(
                      value > 0 ? '+' : '−',
                      value.abs(),
                    ),
              textAlign: TextAlign.center,
              style: AppTypography.rowTitle.copyWith(
                color: value == 0 ? tokens.textTertiary : tokens.accent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _stepButton(
            context,
            icon: Icons.add_rounded,
            onTap: () => _bump(type, 1),
            enabled: value < maxMinutes,
          ),
        ],
      ),
    );
  }

  Widget _stepButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    final tokens = context.tokens;

    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 20),
      color: tokens.accent,
      disabledColor: tokens.textTertiary,
      visualDensity: VisualDensity.compact,
    );
  }
}
