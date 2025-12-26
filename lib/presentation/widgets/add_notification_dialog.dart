import 'package:flutter/material.dart';
import '../../core/models/prayer_time.dart';
import '../../core/models/notification_setting.dart';
import '../utils/prayer_name_helper.dart';
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
      title: const Text('Bildirim Ekle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<PrayerType>(
            key: const Key('prayer_dropdown'),
            value: _selectedPrayer,
            decoration: const InputDecoration(
              labelText: 'Vakit',
              border: OutlineInputBorder(),
            ),
            items: PrayerNameHelper.getAllPrayerTypes().map((prayer) {
              return DropdownMenuItem(
                value: prayer,
                child: Text(PrayerNameHelper.getName(prayer)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPrayer = value;
              });
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Vaktinde'),
                  selected: !_isBefore,
                  onSelected: (_) {
                    setState(() {
                      _isBefore = false;
                      _selectedOffset = 0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Vakitten önce'),
                  selected: _isBefore,
                  onSelected: (_) {
                    setState(() {
                      _isBefore = true;
                      if (_selectedOffset == 0) {
                        _selectedOffset = 5;
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          if (_isBefore) ...[
            const SizedBox(height: 12),
            OffsetPicker(
              maxOffset: _maxOffsetFor(_selectedPrayer),
              value: _selectedOffset,
              onChanged: (value) {
                setState(() {
                  _selectedOffset = value;
                });
              },
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('cancel_button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          key: const Key('save_button'),
          onPressed: _selectedPrayer == null
              ? null
              : () async {
                  final maxOffset = _maxOffsetFor(_selectedPrayer);
                  if (_isBefore &&
                      maxOffset != null &&
                      _selectedOffset > maxOffset) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Bu vakitten en fazla $maxOffset dk önce bildirim ekleyebilirsin.',
                        ),
                      ),
                    );
                    return;
                  }
                  await widget.onAdd(
                    _selectedPrayer!,
                    _isBefore ? _selectedOffset : 0,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}
