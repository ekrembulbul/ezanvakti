import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/models/notification_setting.dart';
import '../../../core/utils/prayer_utils.dart';

class PermissionWarningCard extends StatelessWidget {
  final VoidCallback? onRequestPermission;

  const PermissionWarningCard({super.key, this.onRequestPermission});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withValues(alpha: 0.2),
            Colors.orange.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_off_rounded,
              color: Colors.orange,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bildirim İzni Gerekli',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bildirimleri almak için izin vermeniz gerekiyor.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRequestPermission,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'İzin Ver',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final NotificationSetting setting;
  final bool hasPermission;
  final VoidCallback? onToggle;
  final Future<void> Function()? onDelete;
  final VoidCallback? onTap;

  const NotificationTile({
    super.key,
    required this.setting,
    required this.hasPermission,
    this.onToggle,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = PrayerUtils.getPrayerName(setting.prayerType);
    final icon = PrayerUtils.getPrayerIcon(setting.prayerType);
    final offsetText = setting.minutesBefore == 0
        ? 'Tam vaktinde'
        : '${setting.minutesBefore} dk önce';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: setting.isActive ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: setting.isActive
                ? AppTheme.gold.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: setting.isActive
                    ? AppTheme.gold.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: setting.isActive ? AppTheme.gold : Colors.white54,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: setting.isActive ? Colors.white : Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: setting.isActive
                          ? AppTheme.gold.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      offsetText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: setting.isActive
                            ? AppTheme.gold
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: setting.isActive,
              onChanged: hasPermission ? (_) => onToggle?.call() : null,
              activeColor: AppTheme.gold,
              inactiveThumbColor: Colors.white38,
              inactiveTrackColor: Colors.white12,
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddNotificationBottomSheet extends StatefulWidget {
  final void Function(PrayerType prayerType, int minutesBefore) onAdd;
  final PrayerTime? prayerTime;
  final NotificationSetting? initialSetting;
  final String? submitLabel;
  final String? title;

  const AddNotificationBottomSheet({
    super.key,
    required this.onAdd,
    this.prayerTime,
    this.initialSetting,
    this.submitLabel,
    this.title,
  });

  @override
  State<AddNotificationBottomSheet> createState() =>
      _AddNotificationBottomSheetState();
}

class _AddNotificationBottomSheetState
    extends State<AddNotificationBottomSheet> {
  late PrayerType _selectedType;
  bool _isBefore = false;
  int _selectedOffset = 5;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSetting;
    _selectedType = initial?.prayerType ?? PrayerType.fajr;
    _isBefore = (initial?.minutesBefore ?? 0) > 0;
    _selectedOffset = initial?.minutesBefore ?? 5;
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

  int _maxOffsetFor(PrayerType prayer) {
    // İmsak (fajr) için sabit üst sınır: 300 dk
    if (prayer == PrayerType.fajr) return 300;
    if (widget.prayerTime == null) return 300;
    final previous = _previousPrayer(prayer);
    if (previous == null) return 300;

    final currentTime = _timeFor(prayer);
    final previousTime = _timeFor(previous);
    if (currentTime == null || previousTime == null) return 300;

    final diff = currentTime.difference(previousTime).inMinutes;
    final maxOffset = diff - 1;
    return maxOffset < 1 ? 1 : maxOffset;
  }

  void _ensureOffsetWithinMax() {
    final maxOffset = _maxOffsetFor(_selectedType);
    if (_selectedOffset < 1) _selectedOffset = 1;
    if (_selectedOffset > maxOffset) _selectedOffset = maxOffset;
  }

  void _onSave() {
    final maxOffset = _maxOffsetFor(_selectedType);
    int minutes = 0;

    if (_isBefore) {
      if (_selectedOffset <= 0) {
        setState(() => _errorText = 'En az 1 dk önce olabilir');
        return;
      }

      if (_selectedOffset > maxOffset) {
        setState(() {
          _errorText =
              'Bu vakitten en fazla $maxOffset dk önce bildirim ekleyebilirsin.';
        });
        return;
      }

      minutes = _selectedOffset;
    }

    setState(() => _errorText = null);

    Navigator.of(context).pop();
    widget.onAdd(_selectedType, minutes);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? 'Yeni Bildirim Ekle';
    final submitLabel = widget.submitLabel ?? 'Bildirim Ekle';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: AppTheme.nightGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hangi vakitte bildirim almak istiyorsunuz?',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),
          _buildSectionLabel('Namaz Vakti'),
          const SizedBox(height: 12),
          _buildPrayerTypeSelector(),
          const SizedBox(height: 24),
          _buildSectionLabel('Bildirim Zamanı'),
          const SizedBox(height: 12),
          _buildTimeSelector(),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                submitLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Center(
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.gold.withValues(alpha: 0.8),
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildPrayerTypeSelector() {
    return Center(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        children: PrayerType.values.map((type) {
          final isSelected = type == _selectedType;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedType = type;
              _ensureOffsetWithinMax();
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.gold.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.gold
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PrayerUtils.getPrayerIcon(type),
                    size: 18,
                    color: isSelected ? AppTheme.gold : Colors.white54,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    PrayerUtils.getPrayerName(type),
                    style: TextStyle(
                      color: isSelected ? AppTheme.gold : Colors.white,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeSelector() {
    final maxOffset = _maxOffsetFor(_selectedType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            children: [
              _buildTimeChip(
                label: 'Tam vaktinde',
                isSelected: !_isBefore,
                onTap: () {
                  setState(() {
                    _isBefore = false;
                    _errorText = null;
                  });
                },
              ),
              _buildTimeChip(
                label: 'Öncesinde',
                isSelected: _isBefore,
                onTap: () {
                  setState(() {
                    _isBefore = true;
                    if (_selectedOffset <= 0) {
                      _selectedOffset = 5;
                    }
                    _ensureOffsetWithinMax();
                    _errorText = null;
                  });
                },
              ),
            ],
          ),
        ),
        if (_isBefore) ...[
          const SizedBox(height: 12),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 240),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _errorText != null
                      ? Colors.red.withValues(alpha: 0.6)
                      : AppTheme.gold.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.access_time_rounded,
                          color: AppTheme.gold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dakika seçin',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '1 - $maxOffset dk (İmsak için 300)',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 140,
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: (_selectedOffset - 1).clamp(
                          0,
                          maxOffset - 1,
                        ),
                      ),
                      magnification: 1.1,
                      squeeze: 1.05,
                      useMagnifier: true,
                      itemExtent: 36,
                      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                        background: Colors.white.withValues(alpha: 0.08),
                      ),
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _selectedOffset = index + 1;
                          _errorText = null;
                        });
                      },
                      children: List.generate(
                        maxOffset,
                        (i) => Center(
                          child: Text(
                            '${i + 1} dk',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _errorText!,
                      style: TextStyle(
                        color: Colors.red.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimeChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.gold.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.gold
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.gold : Colors.white,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
