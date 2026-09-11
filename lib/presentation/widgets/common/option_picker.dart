import 'package:flutter/material.dart';
import '../../utils/directional_icons.dart';

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

  /// Alt sayfada grup başlığı. Ardışık seçeneklerin grubu değişince başlık
  /// çizilir; hiçbir seçenek grup taşımıyorsa alt sayfa düz listedir.
  final String? group;

  const OptionItem({
    required this.value,
    required this.label,
    this.description,
    this.icon,
    this.group,
  });
}

const Key kOptionSheetKey = Key('option_sheet');
const Key kOptionSheetHandleKey = Key('option_sheet_handle');
const Key kOptionValueKey = Key('option_value');

/// Alt sayfanın ekrana oranla en büyük yüksekliği. Uzun listede (11 bildirim
/// noktası + açıklamaları) sayfa boydan boya dolup durum çubuğunun altına
/// giriyor ve dışında dokunacak yer kalmıyordu.
const double _kSheetMaxHeightFraction = 0.75;

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
        // Yatay bosluk yok: ayni listedeki SwitchListTile'lar
        // contentPadding.zero kullaniyor, satirlar ayni hizada baslamali.
        padding: const EdgeInsets.symmetric(vertical: 12),
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
            Icon(context.forwardChevron, size: 20, color: tokens.textTertiary),
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
    // Durum çubuğunun altına girmesin; yükseklik sınırı sayfanın içinde
    // (bkz. _OptionSheet), üstte her zaman dokunulup kapatılacak şerit kalır.
    useSafeArea: true,
    builder: (context) =>
        _OptionSheet<T>(title: title, items: items, selected: selected),
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

    // Sınır rota bağlamının MediaQuery'sinden okunur: çağıranın bağlamı bir
    // sarmalayıcıyla daraltılmış olabilir.
    final maxHeight =
        MediaQuery.sizeOf(context).height * _kSheetMaxHeightFraction;

    return SafeArea(
      top: false,
      child: Container(
        key: kOptionSheetKey,
        constraints: BoxConstraints(maxHeight: maxHeight),
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.backgroundStops[1],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tutamaç: sayfanın sürüklenerek kapanabildiğini söyler.
            Center(
              child: Container(
                key: kOptionSheetHandleKey,
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: SectionLabel(title),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, i) => _entry(context, i),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Satır; grubu bir öncekinden farklıysa üstüne grup başlığı gelir.
  Widget _entry(BuildContext context, int index) {
    final item = items[index];
    final group = item.group;
    final startsGroup =
        group != null && (index == 0 || items[index - 1].group != group);
    if (!startsGroup) return _row(context, item);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, index == 0 ? 8 : 16, 20, 2),
          child: SectionLabel(group),
        ),
        _row(context, item),
      ],
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
