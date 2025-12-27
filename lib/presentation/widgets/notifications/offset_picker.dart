import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

class OffsetPicker extends StatefulWidget {
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
  State<OffsetPicker> createState() => _OffsetPickerState();
}

class _OffsetPickerState extends State<OffsetPicker> {
  late TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(OffsetPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value.toString();
      _errorText = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validateAndUpdate(String text) {
    if (text.isEmpty) {
      setState(() => _errorText = 'Dakika giriniz');
      return;
    }

    final value = int.tryParse(text);
    if (value == null) {
      setState(() => _errorText = 'Geçerli bir sayı giriniz');
      return;
    }

    if (value < 1) {
      setState(() => _errorText = 'En az 1 dakika olmalı');
      return;
    }

    final max = (widget.maxOffset ?? 240).clamp(1, 240);
    if (value > max) {
      setState(() {
        _errorText = widget.maxOffset != null
            ? 'En fazla ${widget.maxOffset} dk önce olabilir'
            : 'En fazla $max dk önce olabilir';
      });
      return;
    }

    setState(() => _errorText = null);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final max = (widget.maxOffset ?? 120).clamp(1, 240);
    final displayValue = widget.value.clamp(1, max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kaç dakika önce?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _errorText != null
                            ? Colors.red.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.1),
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: InputBorder.none,
                        hintText: '5',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              'dk',
                              style: TextStyle(
                                color: AppTheme.gold.withValues(alpha: 0.7),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      onChanged: _validateAndUpdate,
                      onSubmitted: _validateAndUpdate,
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 14,
                          color: Colors.red.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _errorText!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    color: AppTheme.gold,
                    size: 28,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$displayValue',
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'dk',
                    style: TextStyle(
                      color: AppTheme.gold.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.gold,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            thumbColor: AppTheme.gold,
            overlayColor: AppTheme.gold.withValues(alpha: 0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            trackHeight: 4,
          ),
          child: Slider(
            value: displayValue.toDouble(),
            min: 1,
            max: max.toDouble(),
            divisions: max,
            onChanged: (v) {
              final rounded = v.round();
              _controller.text = rounded.toString();
              setState(() => _errorText = null);
              widget.onChanged(rounded);
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1 dk',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: widget.maxOffset != null
                    ? Colors.orange.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.maxOffset != null
                      ? Colors.orange.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.maxOffset != null) ...[
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 12,
                      color: Colors.orange.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    widget.maxOffset != null
                        ? 'Maksimum ${widget.maxOffset} dk'
                        : 'Önerilen: 1-$max dk',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: widget.maxOffset != null
                          ? Colors.orange.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$max dk',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
