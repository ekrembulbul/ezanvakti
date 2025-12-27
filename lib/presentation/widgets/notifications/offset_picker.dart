import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class OffsetPicker extends StatelessWidget {
  final int value;
  final int? maxOffset;
  final ValueChanged<int> onChanged;

  const OffsetPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.maxOffset,
  });

  @override
  Widget build(BuildContext context) {
    final max = (maxOffset ?? 120).clamp(1, 240);
    final displayValue = value.clamp(1, max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Dakika',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$displayValue dk önce',
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.gold,
            inactiveTrackColor: Colors.white.withOpacity(0.1),
            thumbColor: AppTheme.gold,
            overlayColor: AppTheme.gold.withOpacity(0.2),
            valueIndicatorColor: AppTheme.gold,
            valueIndicatorTextStyle: const TextStyle(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          child: Slider(
            value: displayValue.toDouble(),
            min: 1,
            max: max.toDouble(),
            divisions: max,
            label: '$displayValue',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          maxOffset == null
              ? 'Önerilen aralık: 1-$max dk'
              : 'En fazla $maxOffset dk önce',
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
        ),
      ],
    );
  }
}
