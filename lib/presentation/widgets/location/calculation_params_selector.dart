import 'package:flutter/material.dart';
import '../../../l10n/l10n_extensions.dart';

import '../../../core/models/calculation_params.dart';
import '../../../core/theme/tokens_context.dart';

/// Konuma özel hesaplama parametrelerini (yöntem, İkindi mezhebi, yüksek enlem
/// düzeltmesi) seçtiren ortak form. Hem konum ekleme hem düzenleme ekranı
/// kullanır. Politika (ör. yöntem değişince mezhep varsayılanı) çağıran ekrana
/// aittir; bu widget yalnızca değişiklikleri bildirir.
class CalculationParamsSelector extends StatelessWidget {
  final int method;
  final AsrSchool school;
  final LatitudeAdjustment latitudeAdjustment;
  final ValueChanged<int> onMethodChanged;
  final ValueChanged<AsrSchool> onSchoolChanged;
  final ValueChanged<LatitudeAdjustment> onLatitudeAdjustmentChanged;

  const CalculationParamsSelector({
    super.key,
    required this.method,
    required this.school,
    required this.latitudeAdjustment,
    required this.onMethodChanged,
    required this.onSchoolChanged,
    required this.onLatitudeAdjustmentChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LabeledDropdown<int>(
          label: context.l10n.calcMethodLabel,
          value: method,
          items: [
            for (final m in CalculationMethods.all)
              DropdownMenuItem(value: m.id, child: Text(m.name)),
          ],
          onChanged: (value) {
            if (value != null) onMethodChanged(value);
          },
        ),
        const SizedBox(height: 16),
        _LabeledDropdown<AsrSchool>(
          label: context.l10n.calcAsrLabel,
          value: school,
          items: [
            for (final s in AsrSchool.values)
              DropdownMenuItem(value: s, child: Text(context.l10n.asrSchoolLabel(s))),
          ],
          onChanged: (value) {
            if (value != null) onSchoolChanged(value);
          },
        ),
        const SizedBox(height: 16),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8),
            iconColor: tokens.accent,
            collapsedIconColor: tokens.textTertiary,
            title: Text(
              context.l10n.calcAdvanced,
              style: TextStyle(
                color: tokens.textPrimary.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            children: [
              _LabeledDropdown<LatitudeAdjustment>(
                label: context.l10n.calcLatitudeLabel,
                value: latitudeAdjustment,
                items: [
                  for (final a in LatitudeAdjustment.values)
                    DropdownMenuItem(
                      value: a,
                      child: Text(context.l10n.latitudeAdjustmentLabel(a)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) onLatitudeAdjustmentChanged(value);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: tokens.textPrimary.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: tokens.backgroundStops[1],
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: tokens.textTertiary,
              ),
              style: TextStyle(color: tokens.textPrimary, fontSize: 15),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
