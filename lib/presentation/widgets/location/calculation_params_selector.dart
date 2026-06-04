import 'package:flutter/material.dart';

import '../../../core/models/calculation_params.dart';
import '../../../core/theme/app_theme.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LabeledDropdown<int>(
          label: 'Hesaplama Yöntemi',
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
          label: 'İkindi (Mezhep)',
          value: school,
          items: [
            for (final s in AsrSchool.values)
              DropdownMenuItem(value: s, child: Text(s.label)),
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
            iconColor: AppTheme.gold,
            collapsedIconColor: Colors.white.withValues(alpha: 0.5),
            title: Text(
              'Gelişmiş',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            children: [
              _LabeledDropdown<LatitudeAdjustment>(
                label: 'Yüksek Enlem Düzeltmesi',
                value: latitudeAdjustment,
                items: [
                  for (final a in LatitudeAdjustment.values)
                    DropdownMenuItem(value: a, child: Text(a.label)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: AppTheme.primaryMedium,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
