import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/models/notification_setting.dart';
import '../../../core/utils/prayer_utils.dart';
import '../common/section_label.dart';
import '../../../core/constants/notification_constants.dart';

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
  static const int _defaultOffset = 15;
  bool _isBefore = false;
  int _selectedOffset = _defaultOffset;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSetting;
    _selectedType = initial?.prayerType ?? PrayerType.fajr;
    _isBefore = (initial?.minutesBefore ?? 0) > 0;
    _selectedOffset = initial?.minutesBefore ?? _defaultOffset;
  }

  int _maxOffsetFor(PrayerType prayer) {
    return NotificationConstants.getMaxMinutesBefore(prayer);
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

  int _normalizedOffset(int value) {
    if (value <= 0) return _defaultOffset;
    final max = _maxOffsetFor(_selectedType);
    return value > max ? max : value;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? 'Yeni Bildirim Ekle';
    final submitLabel = widget.submitLabel ?? 'Bildirim Ekle';

    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 16 + viewInsets,
      ),
      decoration: BoxDecoration(
        gradient: tokens.backgroundGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: AppTypography.counterLabel.copyWith(
                  fontSize: 20,
                  letterSpacing: -0.4,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hangi vakitte bildirim almak istiyorsunuz?',
                style: TextStyle(color: tokens.textSecondary),
              ),
              const SizedBox(height: 24),
              const Center(child: SectionLabel('Namaz Vakti')),
              const SizedBox(height: 12),
              _buildPrayerTypeSelector(),
              const SizedBox(height: 24),
              const Center(child: SectionLabel('Bildirim Zamanı')),
              const SizedBox(height: 12),
              _buildTimeSelector(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.accent,
                    foregroundColor: tokens.backgroundStops.last,
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
            ],
          ),
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
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? tokens.accent.withValues(alpha: 0.2)
                    : tokens.border,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? tokens.accent : tokens.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PrayerUtils.getPrayerIcon(type),
                    size: 18,
                    color: isSelected ? tokens.accent : tokens.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    PrayerUtils.getPrayerName(type),
                    style: TextStyle(
                      color: isSelected ? tokens.accent : tokens.textPrimary,
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
                    _selectedOffset = 0;
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
                    _selectedOffset = _normalizedOffset(_selectedOffset);
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
              constraints: const BoxConstraints(maxWidth: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _errorText != null
                      ? Theme.of(
                          context,
                        ).colorScheme.error.withValues(alpha: 0.6)
                      : tokens.accent.withValues(alpha: 0.4),
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
                          color: tokens.accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.access_time_rounded,
                          color: tokens.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Dakika seçin',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.rowSubtitle.copyWith(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '1 - $maxOffset dk',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.sectionLabel.copyWith(
                                color: tokens.textSecondary,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
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
                      // Seçim bandı tekerleğin *üstüne* çizilir; opak bir renk
                      // seçili satırı tamamen örter. `surface` açık temada opak
                      // beyaz, bu yüzden yatak rengi (mürekkep %5) kullanılıyor.
                      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                        background: tokens.trackSurface,
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
                            style: TextStyle(
                              color: tokens.textPrimary,
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
                        color: Theme.of(context).colorScheme.error,
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
              ? tokens.accent.withValues(alpha: 0.2)
              : tokens.border,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? tokens.accent : tokens.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? tokens.accent : tokens.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  /// Yardımcı metotların hepsi renk okuyor; tek kısayol.
  AppTokens get tokens => context.tokens;

  @override
  void dispose() {
    super.dispose();
  }
}
