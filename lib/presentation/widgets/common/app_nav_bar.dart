import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

const Duration _kNavAnimation = Duration(milliseconds: 220);
const double _kMaxWidth = 600;
const double _kDockRadius = 24;
const double _kItemRadius = 18;
const double _kItemGap = 4;
const double _kItemPadding = 6;
const double _kIconSize = 24;
const double _kLabelGap = 6;
const double _kMinimumTarget = 48;

/// Alt gezinme çubuğundaki tek bir hedef.
class NavItem {
  final String label;
  final IconData icon;

  const NavItem({required this.label, required this.icon});
}

/// İsimlerin tamamını gösteren alt gezinme çubuğu.
/// Büyük metinde iki sütuna geçer; yüksekliğini içerikten alır.
class AppNavBar extends StatelessWidget {
  final List<NavItem> items;
  final int selected;
  final ValueChanged<int> onChanged;

  const AppNavBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  }) : assert(items.length > 0),
       assert(selected >= 0 && selected < items.length);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kMaxWidth),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(_kDockRadius),
                border: Border.all(color: tokens.border),
                boxShadow: [
                  BoxShadow(
                    color: tokens.controlShadow,
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    _buildItems(context, constraints.maxWidth),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItems(BuildContext context, double width) {
    final widths = _minimumWidths(context);
    final available = width - _kItemGap * (items.length - 1);
    final minimum = widths.fold<double>(0, (sum, width) => sum + width);

    if (minimum <= available) {
      final extra = (available - minimum) / items.length;
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: _kItemGap),
              SizedBox(width: widths[i] + extra, child: _button(i)),
            ],
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < items.length; row += 2) ...[
          if (row > 0) const SizedBox(height: _kItemGap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _button(row, horizontal: true)),
                const SizedBox(width: _kItemGap),
                if (row + 1 < items.length)
                  Expanded(child: _button(row + 1, horizontal: true))
                else
                  const Spacer(),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<double> _minimumWidths(BuildContext context) {
    // En kalın etiketi ölç: seçim değiştiğinde hedefler yer değiştirmesin.
    final style = _labelStyle(context, selected: true);
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.localeOf(context),
      maxLines: 1,
    );
    try {
      return [
        for (final item in items) _measureItem(painter, item.label, style),
      ];
    } finally {
      painter.dispose();
    }
  }

  double _measureItem(TextPainter painter, String label, TextStyle style) {
    painter.text = TextSpan(text: label, style: style);
    painter.layout();
    return math.max(
      _kMinimumTarget,
      painter.width.ceilToDouble() + _kItemPadding * 2,
    );
  }

  Widget _button(int index, {bool horizontal = false}) => _NavButton(
    item: items[index],
    isSelected: index == selected,
    horizontal: horizontal,
    onTap: () => onChanged(index),
  );
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final bool isSelected;
  final bool horizontal;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isSelected,
    required this.horizontal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final icon = Icon(
      item.icon,
      size: _kIconSize,
      color: isSelected ? tokens.accent : tokens.textSecondary,
    );
    final label = Text(
      item.label,
      textAlign: horizontal ? TextAlign.start : TextAlign.center,
      style: _labelStyle(context, selected: isSelected),
    );

    return Semantics(
      container: true,
      button: true,
      selected: isSelected,
      label: item.label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: _kNavAnimation,
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: _kMinimumTarget),
          decoration: BoxDecoration(
            color: isSelected
                ? tokens.accent.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(_kItemRadius),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(_kItemRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _kItemPadding,
                  vertical: 8,
                ),
                child: horizontal
                    ? Row(
                        children: [
                          icon,
                          const SizedBox(width: _kLabelGap),
                          Expanded(child: label),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          icon,
                          const SizedBox(height: _kLabelGap),
                          label,
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

TextStyle _labelStyle(BuildContext context, {required bool selected}) =>
    AppTypography.tabLabel.copyWith(
      fontSize: 13,
      height: 1.2,
      color: selected ? context.tokens.accent : context.tokens.textSecondary,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      fontVariations: [FontVariation('wght', selected ? 700 : 600)],
    );
