import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import 'animated_reorder_column.dart';

/// Ayıraçlı satır grubu.
///
/// Tasarımın "kart içinde kart yok" kuralı gereği tek yüzey seviyesi kullanır:
/// grup bir yüzey, içindeki satırlar ayıraçla bölünür.
class GroupedList extends StatelessWidget {
  final List<Widget> children;

  /// Key'li satırların yeni sıralarına kayarak geçmesini sağlar.
  final bool animateOrder;

  const GroupedList({
    super.key,
    required this.children,
    this.animateOrder = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // Kayarken üst üste gelen satırların metinleri birbirine karışmasın.
    final surface = animateOrder
        ? Color.alphaBlend(tokens.surface, tokens.backgroundStops.last)
        : tokens.surface;
    final rows = <Widget>[
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0)
          Divider(height: 1, thickness: 1, indent: 52, color: tokens.divider),
        if (animateOrder)
          ColoredBox(
            key: children[i].key == null ? null : ValueKey(children[i].key),
            color: surface,
            child: children[i],
          )
        else
          children[i],
      ],
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: animateOrder
          ? AnimatedReorderColumn(children: rows)
          : Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

/// [GroupedList] içindeki tek satır: ikon · başlık/alt metin · sağ öğe.
class GroupedRow extends StatelessWidget {
  final IconData? icon;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// İkonun rengi. Varsayılan Metin2; satırın türünü vurgulamak gerektiğinde
  /// (ör. "SIRADAKİ" kartındaki alarm satırı) `accent` verilir.
  final Color? iconColor;

  /// Satır yüksekliği. Varsayılan tam genişlikli listeler içindir; kompakt
  /// kartlar içerik ve metin ölçeğine uygun yüksekliği çağrı noktasında verir.
  /// [growWithContent] açıksa minimum yükseklik olarak kullanılır.
  final double height;

  /// Büyük metinde satırın bu yüksekliği aşmasına izin verir.
  final bool growWithContent;

  /// Pasif satırlar (kapalı bildirim gibi) söndürülür.
  final bool dimmed;

  const GroupedRow({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.height = 74,
    this.growWithContent = false,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final row = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: height,
        maxHeight: growWithContent ? double.infinity : height,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: growWithContent ? 12 : 0,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              SizedBox(
                width: 22,
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor ?? tokens.textSecondary,
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle.merge(
                    // Uzun başlık satırın genişliğinde kırpılır.
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.rowTitle.copyWith(
                      color: tokens.textPrimary,
                    ),
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    DefaultTextStyle.merge(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.rowSubtitle.copyWith(
                        color: tokens.textSecondary,
                      ),
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    );

    final content = Opacity(opacity: dimmed ? 0.45 : 1.0, child: row);

    if (onTap == null) return content;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
