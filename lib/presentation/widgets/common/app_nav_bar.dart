import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// Gösterge geçişinin süresi. `SlidingSegment` ile aynı sabit: biçimleri
/// farklı, hareket dilleri ortak.
const Duration _kNavAnimation = Duration(milliseconds: 220);

// Dikey yerleşim; toplam [AppNavBar.height] bunların toplamıdır.
const double _kTopPadding = 8;
const double _kIconSize = 26;
const double _kIconLabelGap = 6;

/// Etiketin punto ve satır kutusu birlikte değişir: `height: 1.0` verildiği için
/// satır yüksekliği puntoya eşittir, [_kLabelHeight] ondan küçük olamaz.
const double _kLabelFontSize = 13;
const double _kLabelHeight = 14;
const double _kLabelIndicatorGap = 3;
const double _kIndicatorHeight = 3;
const double _kBottomPadding = 6;

const double _kIndicatorWidth = 26;

/// Seçili ikonun arkasındaki yumuşak zemin. Rengin ve kalınlığın tek başına
/// yetmediği görüldü: açık temada vurgu ile pasif gri yakın tonlar, gösterge
/// de etiketin altında küçük kalıyordu. Zemin ilk bakışta seçileni söylüyor.
const double _kIconBackdropWidth = 46;
const double _kIconBackdropRadius = 12;
const double _kIconBackdropOpacity = 0.14;

/// Göstergenin konumu spec'e bağlı olduğu için test edilebilir.
const Key kNavIndicatorKey = Key('nav_indicator');

/// Kenar boşluğunun iç boşluğa oranı.
///
/// `1` tam eşit aralık (`|---o---o---o---|`) demek; kenardakiler o zaman
/// biraz fazla içeri kaçıyor. `0.5` ise dilimleri eşit bölmenin sonucu
/// (`|-o---o---o-|`), bu sefer kenara fazla yapışıyorlar. Aradaki 2/3
/// ikisinin ortası: `|--o---o---o--|`.
const double _kEdgeGapRatio = 2 / 3;

/// İçeriğin kendi diliminin ortasından ne kadar kaydırılacağı.
///
/// Dilimler genişliği eşit böler, yani merkezler dilim ortalarına çakılı
/// kalır. İstenen yerleşim [_kEdgeGapRatio] ile tanımlanıyor. Kaydırma
/// yalnızca **görsel**; dokunma hedefi dilimin tamamı olarak kalıyor.
double navContentDx(int index, int count, double width) {
  final r = _kEdgeGapRatio;
  // Toplam genislik = 2·kenar + (n-1)·ic. Merkez_i = (r + i) / (2r + n - 1).
  final desired = (r + index) / (2 * r + count - 1);
  final slotCenter = (2 * index + 1) / (2 * count);
  return width * (desired - slotCenter);
}

/// Alt gezinme çubuğundaki tek bir hedef.
class NavItem {
  final String label;
  final IconData icon;

  const NavItem({required this.label, required this.icon});
}

/// Alt gezinme çubuğu: ikon üstte, etiket altta, seçili öğenin altında kayan
/// ince bir çizgi.
///
/// `SlidingSegment`'ten kasten ayrıdır: o ekran içi bir filtre, bu gezinme.
/// İkisi aynı görünseydi kullanıcı hangisinin "neredeyim" hangisinin "ne
/// gösteriyorum" olduğunu ayırt edemezdi.
class AppNavBar extends StatelessWidget {
  static const double height =
      _kTopPadding +
      _kIconSize +
      _kIconLabelGap +
      _kLabelHeight +
      _kLabelIndicatorGap +
      _kIndicatorHeight +
      _kBottomPadding;

  final List<NavItem> items;
  final int selected;
  final ValueChanged<int> onChanged;

  const AppNavBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth = constraints.maxWidth / items.length;

              return Stack(
                fit: StackFit.expand,
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: Transform.translate(
                            offset: Offset(
                              navContentDx(
                                i,
                                items.length,
                                constraints.maxWidth,
                              ),
                              0,
                            ),
                            child: _NavButton(
                              item: items[i],
                              isSelected: i == selected,
                              onTap: () => onChanged(i),
                            ),
                          ),
                        ),
                    ],
                  ),
                  AnimatedPositioned(
                    duration: _kNavAnimation,
                    curve: Curves.easeOutCubic,
                    left:
                        slotWidth * selected +
                        (slotWidth - _kIndicatorWidth) / 2 +
                        navContentDx(
                          selected,
                          items.length,
                          constraints.maxWidth,
                        ),
                    bottom: _kBottomPadding,
                    width: _kIndicatorWidth,
                    height: _kIndicatorHeight,
                    child: DecoratedBox(
                      key: kNavIndicatorKey,
                      decoration: BoxDecoration(
                        color: tokens.accent,
                        borderRadius: BorderRadius.circular(
                          _kIndicatorHeight / 2,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavButton({
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
      child: Padding(
        padding: const EdgeInsets.only(top: _kTopPadding),
        child: Column(
          // `min` olursa Column icerige kuculur ve Row'un varsayilan `center`
          // hizalamasi onu dikeyde ortalar; etiket asagi kayip gostergenin
          // bandina girer. `max` ile icerik ustten baslar, gosterge altta kalir.
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(
              height: _kIconSize,
              width: _kIconBackdropWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isSelected
                      ? tokens.accent.withValues(alpha: _kIconBackdropOpacity)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(_kIconBackdropRadius),
                ),
                child: Icon(item.icon, size: _kIconSize, color: color),
              ),
            ),
            const SizedBox(height: _kIconLabelGap),
            SizedBox(
              height: _kLabelHeight,
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.tabLabel.copyWith(
                  fontSize: _kLabelFontSize,
                  height: 1.0,
                  color: color,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontVariations: [
                    FontVariation('wght', isSelected ? 700 : 600),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
