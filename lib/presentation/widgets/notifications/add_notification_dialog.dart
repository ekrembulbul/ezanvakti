import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/models/notification_setting.dart';
import '../../../core/utils/prayer_utils.dart';
import 'offset_picker.dart';

class AddNotificationDialog extends StatefulWidget {
  final PrayerTime? prayerTime;
  final Future<void> Function(PrayerType, int) onAdd;

  const AddNotificationDialog({
    super.key,
    this.prayerTime,
    required this.onAdd,
  });

  @override
  State<AddNotificationDialog> createState() => _AddNotificationDialogState();
}

class _AddNotificationDialogState extends State<AddNotificationDialog> {
  PrayerType? _selectedPrayer;
  bool _isBefore = false;
  int _selectedOffset = 5;

  int? _maxOffsetFor(PrayerType? prayer) {
    if (prayer == null || widget.prayerTime == null) return null;
    final previous = _previousPrayer(prayer);
    if (previous == null) return null;

    final currentTime = _timeFor(prayer);
    final previousTime = _timeFor(previous);
    if (currentTime == null || previousTime == null) return null;

    final diff = currentTime.difference(previousTime).inMinutes;
    final maxOffset = diff - 1;
    return maxOffset < 1 ? 1 : maxOffset;
  }

  PrayerType? _previousPrayer(PrayerType prayer) {
    switch (prayer) {
      case PrayerType.fajr:
        return null;
      case PrayerType.sunrise:
        return PrayerType.fajr;
      case PrayerType.dhuhr:
        return PrayerType.sunrise;
      case PrayerType.asr:
        return PrayerType.dhuhr;
      case PrayerType.maghrib:
        return PrayerType.asr;
      case PrayerType.isha:
        return PrayerType.maghrib;
    }
  }

  DateTime? _timeFor(PrayerType prayer) {
    final pt = widget.prayerTime;
    if (pt == null) return null;
    switch (prayer) {
      case PrayerType.fajr:
        return pt.fajr;
      case PrayerType.sunrise:
        return pt.sunrise;
      case PrayerType.dhuhr:
        return pt.dhuhr;
      case PrayerType.asr:
        return pt.asr;
      case PrayerType.maghrib:
        return pt.maghrib;
      case PrayerType.isha:
        return pt.isha;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.primaryMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Bildirim Ekle',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vakit Seçin',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.gold.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<PrayerType>(
                key: const Key('prayer_dropdown'),
                value: _selectedPrayer,
                hint: Text(
                  'Vakit seçiniz',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                ),
                isExpanded: true,
                dropdownColor: AppTheme.primaryMedium,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                items: PrayerType.values.map((prayer) {
                  return DropdownMenuItem(
                    value: prayer,
                    child: Row(
                      children: [
                        Icon(
                          PrayerUtils.getPrayerIcon(prayer),
                          size: 18,
                          color: AppTheme.gold,
                        ),
                        const SizedBox(width: 10),
                        Text(PrayerUtils.getPrayerName(prayer)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedPrayer = value),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Bildirim Zamanı',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.gold.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTimeChoice(
                  label: 'Vaktinde',
                  isSelected: !_isBefore,
                  onTap: () => setState(() {
                    _isBefore = false;
                    _selectedOffset = 0;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTimeChoice(
                  label: 'Öncesinde',
                  isSelected: _isBefore,
                  onTap: () => setState(() {
                    _isBefore = true;
                    if (_selectedOffset == 0) _selectedOffset = 5;
                  }),
                ),
              ),
            ],
          ),
          if (_isBefore) ...[
            const SizedBox(height: 16),
            OffsetPicker(
              maxOffset: _maxOffsetFor(_selectedPrayer),
              value: _selectedOffset,
              onChanged: (value) => setState(() => _selectedOffset = value),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('cancel_button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          key: const Key('save_button'),
          onPressed: _selectedPrayer == null ? null : _onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.gold,
            foregroundColor: AppTheme.primaryDark,
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Ekle',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeChoice({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.gold.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.gold
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.gold : Colors.white,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    final maxOffset = _maxOffsetFor(_selectedPrayer);
    if (_isBefore && maxOffset != null && _selectedOffset > maxOffset) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bu vakitten en fazla $maxOffset dk önce bildirim ekleyebilirsin.',
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }
    await widget.onAdd(_selectedPrayer!, _isBefore ? _selectedOffset : 0);
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}
