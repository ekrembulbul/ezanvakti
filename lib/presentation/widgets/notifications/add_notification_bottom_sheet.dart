import 'package:flutter/cupertino.dart';
import '../../../l10n/l10n_extensions.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/models/derived_time.dart';
import '../../../core/models/notification_setting.dart';
import '../../../core/utils/prayer_utils.dart';
import '../common/section_label.dart';
import '../../../core/constants/notification_constants.dart';

class AddNotificationBottomSheet extends StatefulWidget {
  /// [weekdays] boş küme = her gün; [label] boşsa varsayılan başlık kullanılır.
  final void Function(
    PrayerType prayerType,
    int minutesBefore,
    Set<int> weekdays,
    String? label,
    DerivedTimeKind? derivedKind,
  )
  onAdd;
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

  /// Seçili türetilmiş nokta; null ise satır bir namaz vakti içindir.
  DerivedTimeKind? _derivedKind;

  /// UI'da her zaman 7 gün seçili gösterilir; modelde "hepsi" boş kümedir.
  late Set<int> _weekdays;
  late TextEditingController _label;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSetting;
    _selectedType = initial?.prayerType ?? PrayerType.fajr;
    _derivedKind = initial?.derivedKind;
    _isBefore = (initial?.minutesBefore ?? 0) > 0;
    _selectedOffset = initial?.minutesBefore ?? _defaultOffset;
    final days = initial?.weekdays ?? const <int>{};
    _weekdays = days.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : {...days};
    _label = TextEditingController(text: initial?.label ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  int _maxOffsetFor(PrayerType prayer) {
    return NotificationConstants.getMaxMinutesBefore(prayer);
  }

  void _onSave() {
    final maxOffset = _maxOffsetFor(_selectedType);
    int minutes = 0;

    if (_isBefore) {
      if (_selectedOffset <= 0) {
        setState(() => _errorText = context.l10n.remindersMinOffsetError);
        return;
      }

      if (_selectedOffset > maxOffset) {
        setState(() {
          _errorText =
              context.l10n.remindersMaxOffsetError(maxOffset);
        });
        return;
      }

      minutes = _selectedOffset;
    }

    setState(() => _errorText = null);

    Navigator.of(context).pop();
    final label = _label.text.trim();
    widget.onAdd(
      _selectedType,
      minutes,
      _weekdays.length == 7 ? const <int>{} : _weekdays,
      label.isEmpty ? null : label,
      _derivedKind,
    );
  }

  void _toggleDay(int day) {
    setState(() {
      if (_weekdays.contains(day)) {
        // En az bir gün kalsın: hiç çalmayan bildirim anlamsız.
        if (_weekdays.length > 1) _weekdays.remove(day);
      } else {
        _weekdays.add(day);
      }
    });
  }

  int _normalizedOffset(int value) {
    if (value <= 0) return _defaultOffset;
    final max = _maxOffsetFor(_selectedType);
    return value > max ? max : value;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? context.l10n.remindersAddTitle;
    final submitLabel = widget.submitLabel ?? context.l10n.remindersAddButton;

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
                context.l10n.remindersWhichPrayer,
                style: TextStyle(color: tokens.textSecondary),
              ),
              const SizedBox(height: 24),
              Center(child: SectionLabel(context.l10n.remindersPrayerSection)),
              const SizedBox(height: 12),
              _buildPrayerTypeSelector(),
              const SizedBox(height: 20),
              Center(child: SectionLabel(context.l10n.remindersDerivedSection)),
              const SizedBox(height: 8),
              Text(
                context.l10n.remindersDerivedHint,
                textAlign: TextAlign.center,
                style: AppTypography.hint.copyWith(
                  color: tokens.textTertiary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              _buildDerivedSelector(),
              const SizedBox(height: 24),
              Center(child: SectionLabel(context.l10n.remindersTimeSection)),
              const SizedBox(height: 12),
              _buildTimeSelector(),
              const SizedBox(height: 24),
              Center(child: SectionLabel(context.l10n.remindersDaysSection)),
              const SizedBox(height: 12),
              _buildWeekdaySelector(),
              const SizedBox(height: 24),
              Center(child: SectionLabel(context.l10n.remindersLabelSection)),
              const SizedBox(height: 12),
              TextField(
                controller: _label,
                style: TextStyle(color: tokens.textPrimary),
                decoration: InputDecoration(
                  hintText: context.l10n.reminderFridayLabel,
                  hintStyle: TextStyle(color: tokens.textTertiary),
                  filled: true,
                  fillColor: tokens.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: tokens.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: tokens.border),
                  ),
                ),
              ),
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

  /// Türetilmiş nokta çipleri. Seçim vaktin **yerine** geçer: bir çipe
  /// dokununca o noktanın çıpa vakti de seçilir; tekrar dokunmak seçimi
  /// kaldırır ve satır yeniden bir vakit bildirimi olur.
  Widget _buildDerivedSelector() {
    return Center(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: DerivedTimeKind.values.map((kind) {
          final isSelected = kind == _derivedKind;
          return GestureDetector(
            onTap: () => setState(() {
              if (isSelected) {
                _derivedKind = null;
              } else {
                _derivedKind = kind;
                _selectedType = kind.anchor;
              }
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? tokens.accent.withValues(alpha: 0.2)
                    : tokens.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? tokens.accent : tokens.border,
                ),
              ),
              child: Text(
                context.l10n.derivedName(kind),
                style: TextStyle(
                  color: isSelected ? tokens.accent : tokens.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Gün çipleri; alarm ekranındaki kalıpla aynı (1=Pazartesi).
  Widget _buildWeekdaySelector() {
    final names = [for (var d = 1; d <= 7; d++) context.l10n.weekdayLetter(d)];

    return Row(
      children: List.generate(7, (index) {
        final day = index + 1;
        final selected = _weekdays.contains(day);
        return Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(end: index < 6 ? 6 : 0),
            child: GestureDetector(
              onTap: () => _toggleDay(day),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? tokens.accent.withValues(alpha: 0.2)
                      : tokens.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? tokens.accent : tokens.border,
                  ),
                ),
                child: Text(
                  names[index],
                  style: TextStyle(
                    color: selected ? tokens.accent : tokens.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
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
                    context.l10n.prayerName(type),
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
                label: context.l10n.remindersOnTimeOption,
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
                label: context.l10n.remindersBeforeOption,
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
                              context.l10n.remindersPickMinutes,
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
}
