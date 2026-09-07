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
const double _kVerticalPadding = 8;
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
                color: tokens.trackSurface,
                borderRadius: BorderRadius.circular(_kDockRadius),
                border: Border.all(color: tokens.trackBorder),
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
    final layout = _layout(context, width);
    final selectedRect = layout.slots[selected];
    final tokens = context.tokens;
    return SizedBox(
      height: layout.height,
      child: Stack(
        children: [
          AnimatedPositionedDirectional(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : _kNavAnimation,
            curve: Curves.easeOutCubic,
            start: selectedRect.left,
            top: selectedRect.top,
            width: selectedRect.width,
            height: selectedRect.height,
            child: DecoratedBox(
              key: const Key('nav_selection'),
              decoration: BoxDecoration(
                color: tokens.selectedControl,
                borderRadius: BorderRadius.circular(_kItemRadius),
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
          for (var i = 0; i < items.length; i++)
            PositionedDirectional(
              start: layout.slots[i].left,
              top: layout.slots[i].top,
              width: layout.slots[i].width,
              height: layout.slots[i].height,
              child: _button(i, horizontal: layout.horizontal),
            ),
        ],
      ),
    );
  }

  ({List<Rect> slots, bool horizontal, double height}) _layout(
    BuildContext context,
    double width,
  ) {
    // En kalın etiketi ölç: seçim değiştiğinde hedefler yer değiştirmesin.
    final style = _labelStyle(context, selected: true);
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.localeOf(context),
    );
    Size measure(String label, {double maxWidth = double.infinity}) {
      painter.text = TextSpan(text: label, style: style);
      painter.layout(maxWidth: maxWidth);
      return painter.size;
    }

    try {
      final labels = [for (final item in items) measure(item.label)];
      final widths = [
        for (final label in labels)
          math.max(
            _kMinimumTarget,
            label.width.ceilToDouble() + _kItemPadding * 2,
          ),
      ];
      final available = width - _kItemGap * (items.length - 1);
      final minimum = widths.fold<double>(
        0,
        (sum, itemWidth) => sum + itemWidth,
      );
      final slots = <Rect>[];
      if (minimum <= available) {
        final extra = (available - minimum) / items.length;
        final labelHeight = labels
            .map((label) => label.height)
            .reduce(math.max)
            .ceilToDouble();
        final height =
            _kIconSize + _kLabelGap + labelHeight + _kVerticalPadding * 2;
        var start = 0.0;
        for (final itemWidth in widths) {
          slots.add(Rect.fromLTWH(start, 0, itemWidth + extra, height));
          start += itemWidth + extra + _kItemGap;
        }
        return (slots: slots, horizontal: false, height: height);
      }

      final slotWidth = (width - _kItemGap) / 2;
      final labelWidth = math.max(
        1.0,
        slotWidth - _kItemPadding * 2 - _kIconSize - _kLabelGap,
      );
      var top = 0.0;
      for (var row = 0; row < items.length; row += 2) {
        var contentHeight = _kIconSize;
        final end = math.min(row + 2, items.length);
        for (var i = row; i < end; i++) {
          contentHeight = math.max(
            contentHeight,
            measure(items[i].label, maxWidth: labelWidth).height.ceilToDouble(),
          );
        }
        final height = math.max(
          _kMinimumTarget,
          contentHeight + _kVerticalPadding * 2,
        );
        for (var i = row; i < end; i++) {
          slots.add(
            Rect.fromLTWH(
              (i - row) * (slotWidth + _kItemGap),
              top,
              slotWidth,
              height,
            ),
          );
        }
        top += height + _kItemGap;
      }
      return (slots: slots, horizontal: true, height: top - _kItemGap);
    } finally {
      painter.dispose();
    }
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kMinimumTarget),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(_kItemRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              focusColor: tokens.accent.withValues(alpha: 0.10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _kItemPadding,
                  vertical: _kVerticalPadding,
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
