import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import 'section_label.dart';

/// Seçici alt sayfasındaki tek bir seçenek.
class OptionItem<T> {
  final T value;
  final String label;

  /// Seçeneğin altında duran açıklama. Kısa tutulmalı; satır iki satıra çıkar.
  final String? description;

  final IconData? icon;

  const OptionItem({
    required this.value,
    required this.label,
    this.description,
    this.icon,
  });
}

const Key kOptionSheetKey = Key('option_sheet');
const Key kOptionValueKey = Key('option_value');

/// Ayar satırı: solda etiket, sağda seçili değer ve chevron.
///
/// Material'ın `DropdownButton`'ı uygulamanın satır diline yabancı kalıyordu:
/// kendi menüsünü, kendi tipografisini ve dar bir dokunma hedefini getiriyor.
/// Bunun yerine satırın tamamı dokunulabilir ve seçenekler alt sayfada açılır —
/// uzun listeler (ses) de aynı bileşenle çalışır.
class OptionRow<T> extends StatelessWidget {
  final String label;
  final T selected;
  final List<OptionItem<T>> items;
  final ValueChanged<T> onChanged;

  /// Alt sayfanın başlığı. Verilmezse [label] kullanılır.
  final String? sheetTitle;

  /// Seçili değer satırda nasıl yazılsın? Verilmezse seçeneğin etiketi.
  final String Function(T value)? valueLabel;

  const OptionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.items,
    required this.onChanged,
    this.sheetTitle,
    this.valueLabel,
  });

  String _currentLabel() {
    if (valueLabel != null) return valueLabel!(selected);
    for (final item in items) {
      if (item.value == selected) return item.label;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showOptionPicker<T>(
          context: context,
          title: sheetTitle ?? label,
          items: items,
          selected: selected,
        );
        if (picked != null) onChanged(picked);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            // Etiket ve deger sabit oranla paylasiyor: deger `Flexible` ile
            // esnek birakilinca kendi diliminin soluna yasliyor ve satirin
            // ortasinda duruyor gibi gorunuyordu.
            Expanded(
              flex: 3,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.rowTitle.copyWith(
                  color: tokens.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Text(
                _currentLabel(),
                key: kOptionValueKey,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.rowSubtitle.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: tokens.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Seçenekleri alt sayfada gösterir; seçilen değeri döner, iptalde `null`.
Future<T?> showOptionPicker<T>({
  required BuildContext context,
  required String title,
  required List<OptionItem<T>> items,
  required T selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _OptionSheet<T>(
      title: title,
      items: items,
      selected: selected,
    ),
  );
}

class _OptionSheet<T> extends StatelessWidget {
  final String title;
  final List<OptionItem<T>> items;
  final T selected;

  const _OptionSheet({
    required this.title,
    required this.items,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SafeArea(
      top: false,
      child: Container(
        key: kOptionSheetKey,
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.backgroundStops[1],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: SectionLabel(title),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, i) => _row(context, items[i]),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, OptionItem<T> item) {
    final tokens = context.tokens;
    final isSelected = item.value == selected;

    return InkWell(
      onTap: () => Navigator.of(context).pop(item.value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            if (item.icon != null) ...[
              Icon(item.icon, size: 20, color: tokens.accent),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: AppTypography.rowTitle.copyWith(
                      color: isSelected ? tokens.accent : tokens.textPrimary,
                    ),
                  ),
                  if (item.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.description!,
                      style: AppTypography.rowSubtitle.copyWith(
                        color: tokens.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded, size: 20, color: tokens.accent),
          ],
        ),
      ),
    );
  }
}
