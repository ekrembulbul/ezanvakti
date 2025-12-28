import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _minutesController = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSetting;
    _selectedType = initial?.prayerType ?? PrayerType.fajr;
    _isBefore = (initial?.minutesBefore ?? 0) > 0;
    _minutesController.text = _isBefore
        ? (initial?.minutesBefore ?? 5).toString()
        : '5';
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

  int? _maxOffsetFor(PrayerType? prayer) {
    if (prayer == null) return null;
    // İmsak (fajr) için sabit üst sınır: 300 dk
    if (prayer == PrayerType.fajr) return 300;
    if (widget.prayerTime == null) return null;
    final previous = _previousPrayer(prayer);
    if (previous == null) return null;

    final currentTime = _timeFor(prayer);
    final previousTime = _timeFor(previous);
    if (currentTime == null || previousTime == null) return null;

    final diff = currentTime.difference(previousTime).inMinutes;
    final maxOffset = diff - 1;
    return maxOffset < 1 ? 1 : maxOffset;
  }

  void _onSave() {
    final maxOffset = _maxOffsetFor(_selectedType);
    int minutes = 0;

    if (_isBefore) {
      final parsed = int.tryParse(_minutesController.text.trim());

      if (parsed == null) {
        setState(() => _errorText = 'Dakika giriniz');
        return;
      }

      if (parsed <= 0) {
        setState(() => _errorText = 'En az 1 dk önce olabilir');
        return;
      }

      if (maxOffset != null && parsed > maxOffset) {
        setState(() {
          _errorText =
              'Bu vakitten en fazla $maxOffset dk önce bildirim ekleyebilirsin.';
        });
        return;
      }

      minutes = parsed;
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
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.gold.withValues(alpha: 0.8),
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildPrayerTypeSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: PrayerType.values.map((type) {
        final isSelected = type == _selectedType;
        return GestureDetector(
          onTap: () => setState(() => _selectedType = type),
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
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeSelector() {
    final maxOffset = _maxOffsetFor(_selectedType);
    final hint = maxOffset != null ? 'Maks $maxOffset dk' : 'Dakika (örn. 5)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
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
                  if (_minutesController.text.isEmpty) {
                    _minutesController.text = '5';
                  }
                  _errorText = null;
                });
              },
            ),
          ],
        ),
        if (_isBefore) ...[
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxWidth: 260),
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
            child: Row(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _minutesController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          border: InputBorder.none,
                          hintText: hint,
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          suffixText: 'dk',
                          suffixStyle: const TextStyle(
                            color: AppTheme.gold,
                            fontWeight: FontWeight.w700,
                          ),
                          helperText:
                              'Maksimum: ${maxOffset ?? 'belirtilmedi'}.',
                          helperStyle: TextStyle(
                            fontSize: 10.5,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                          errorText: _errorText,
                          errorStyle: TextStyle(
                            fontSize: 11,
                            color: Colors.red.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                        onChanged: (_) => setState(() => _errorText = null),
                        onSubmitted: (_) => _onSave(),
                      ),
                    ],
                  ),
                ),
              ],
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
    _minutesController.dispose();
    super.dispose();
  }
}
