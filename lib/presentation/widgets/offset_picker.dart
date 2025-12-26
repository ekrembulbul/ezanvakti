import 'package:flutter/material.dart';

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
          children: [const Text('Dakika'), Text('$displayValue dk önce')],
        ),
        Slider(
          value: displayValue.toDouble(),
          min: 1,
          max: max.toDouble(),
          divisions: max,
          label: '$displayValue',
          onChanged: (v) => onChanged(v.round()),
        ),
        Text(
          maxOffset == null
              ? 'Önerilen aralık: 1-${max} dk'
              : 'En fazla $maxOffset dk önce',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}
