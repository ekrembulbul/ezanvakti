import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// Ayıraçlı satır grubu.
///
/// Tasarımın "kart içinde kart yok" kuralı gereği tek yüzey seviyesi kullanır:
/// grup bir yüzey, içindeki satırlar ayıraçla bölünür.
class GroupedList extends StatelessWidget {
  final List<Widget> children;

  const GroupedList({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                // Ayıraç satırın ikon hizasından başlar.
                indent: 52,
                color: tokens.divider,
              ),
            children[i],
          ],
        ],
      ),
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

  /// Satır yüksekliği. Varsayılan tam genişlikli listeler içindir; "SIRADAKİ"
  /// kartı gibi sıkışık yerlerde spec §6.1/7'deki 62 kullanılır.
  final double height;

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
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final row = SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    // Satır sabit yükseklikte; uzun metin taşmak yerine
                    // kırpılır.
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
