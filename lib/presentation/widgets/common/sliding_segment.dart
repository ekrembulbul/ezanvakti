import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// Kontrol animasyonlarının süresi. Palet geçişinden (400 ms) ayrıdır —
/// kontrol tepkili hissetmelidir.
const Duration _kSegmentAnimation = Duration(milliseconds: 220);

/// Yatağın kenarlık kalınlığı. Kenarlık `padding`'in dışında çizildiği için
/// pill'in yüksekliği ve yarıçapı hesaplanırken iki kez düşülmelidir; spec
/// §4.4'teki 42/r21 (ve tema seçicideki 32/r8) ölçüleri bunu içeriyor.
const double _kTrackBorderWidth = 1;

/// Pill'i test edilebilir kılar; ölçüsü spec'e bağlı olduğu için doğrulanıyor.
const Key kSegmentPillKey = Key('segment_pill');

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
    final pillRadius = radius - padding - _kTrackBorderWidth;

    return Container(
      height: height,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: tokens.trackSurface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: tokens.trackBorder,
          width: _kTrackBorderWidth,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotWidth = constraints.maxWidth / items.length;

          return Stack(
            // Konumlandırılmamış çocuklar yatağın iç kutusunu doldursun.
            // Varsayılan gevşek kısıtta etiket satırı kendi yüksekliğine
            // küçülüp üste yapışıyor, pill'in merkezinden yukarıda kalıyordu.
            fit: StackFit.expand,
            children: [
              AnimatedPositioned(
                duration: _kSegmentAnimation,
                curve: Curves.easeOutCubic,
                left: index < 0 ? 0 : slotWidth * index,
                width: slotWidth,
                // Dikeyde yatağın iç kutusunu birebir doldurur. Yükseklik
                // hesaplamak yerine top/bottom kullanılıyor ki kenarlık ya da
                // dolgu değişse de pill taşmasın.
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  key: kSegmentPillKey,
                  decoration: BoxDecoration(
                    color: tokens.selectedControl,
                    borderRadius: BorderRadius.circular(pillRadius),
                    border: Border.all(
                      color: tokens.accent.withValues(alpha: 0.30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.controlShadow,
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
