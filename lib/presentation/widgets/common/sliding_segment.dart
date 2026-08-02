import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// Kontrol animasyonlarının süresi. Palet geçişinden (400 ms) ayrıdır —
/// kontrol tepkili hissetmelidir.
const Duration _kSegmentAnimation = Duration(milliseconds: 220);

/// [SlidingSegment] içindeki tek bir bölme.
class SegmentItem<T> {
  final T value;
  final String label;
  final IconData? icon;

  const SegmentItem({required this.value, required this.label, this.icon});
}

/// Ortak yatak üzerinde kayan pill'li segment.
///
/// Üç yerde kullanılır: alt gezinme, alarm türü seçimi ve tema seçimi.
/// Ölçüler parametreyle ayarlanır; varsayılanlar alt gezinme içindir.
class SlidingSegment<T> extends StatelessWidget {
  final List<SegmentItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Yatak yüksekliği. Alt gezinme ve alarm türü 52, tema seçimi 40.
  final double height;

  /// Yatak yarıçapı. Alt gezinme ve alarm türü 26, tema seçimi 12.
  final double radius;

  /// Yatağın iç boşluğu; pill bu kadar içeriden başlar.
  final double padding;

  const SlidingSegment({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.height = 52,
    this.radius = 26,
    this.padding = 4,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final index = items.indexWhere((item) => item.value == selected);
    final pillHeight = height - padding * 2;

    return Container(
      height: height,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tokens.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotWidth = constraints.maxWidth / items.length;

          return Stack(
            children: [
              AnimatedPositioned(
                duration: _kSegmentAnimation,
                curve: Curves.easeOutCubic,
                left: index < 0 ? 0 : slotWidth * index,
                width: slotWidth,
                height: pillHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(radius - padding),
                    border: Border.all(
                      color: tokens.accent.withValues(alpha: 0.30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final item in items)
                    Expanded(
                      child: _SegmentButton<T>(
                        item: item,
                        isSelected: item.value == selected,
                        onTap: () => onChanged(item.value),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SegmentButton<T> extends StatelessWidget {
  final SegmentItem<T> item;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = isSelected ? tokens.accent : tokens.textTertiary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (item.icon != null) ...[
            Icon(item.icon, size: 19, color: color),
            const SizedBox(width: 8),
          ],
          Text(
            item.label,
            style: AppTypography.tabLabel.copyWith(
              color: color,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              fontVariations: [FontVariation('wght', isSelected ? 700 : 600)],
            ),
          ),
        ],
      ),
    );
  }
}
