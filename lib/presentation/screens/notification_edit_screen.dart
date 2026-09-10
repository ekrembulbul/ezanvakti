import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/constants/notification_constants.dart';
import '../../core/models/derived_time.dart';
import '../../core/models/notification_draft.dart';
import '../../core/models/notification_setting.dart';
import '../../core/models/prayer_time.dart';
import '../../core/models/reminder_point.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../../core/utils/duration_formatter.dart';
import '../../core/utils/prayer_utils.dart';
import '../../features/notifications/domain/notification_time_rules.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_extensions.dart';
import '../utils/reminder_labels.dart';
import '../utils/time_format_context.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/option_picker.dart';
import '../widgets/common/section_label.dart';

/// Bildirim ekleme/düzenleme sayfası; `AlarmEditScreen` ile aynı kalıp.
///
/// Eskiden alt sayfaydı; hesaplanan vakitlerle uzayınca kapanmaz oldu ve
/// "türetilmiş vakit" çipleri seçilince üstteki vaktin kendiliğinden
/// değişmesi anlaşılmıyordu. Burada hedef tek bir "Ne zaman?" seçicisidir;
/// hesaplanan nokta seçilince formülü, açıklaması ve bugünkü saati yazılır,
/// altta da bildirimin gerçekten ne zaman geleceği gösterilir.
///
/// "Kaydet" [NotificationDraft] ile döner; geri tuşu `null` döndürür.
class NotificationEditScreen extends StatefulWidget {
  final NotificationSetting? initial;

  /// Bugünkü saatler ve önizleme için; boşsa yalnız o satırlar gizlenir.
  final List<PrayerTime> prayerTimes;

  /// Testler sabitler; varsayılan cihaz saati.
  final DateTime Function()? clock;

  const NotificationEditScreen({
    super.key,
    this.initial,
    required this.prayerTimes,
    this.clock,
  });

  @override
  State<NotificationEditScreen> createState() => _NotificationEditScreenState();
}

class _NotificationEditScreenState extends State<NotificationEditScreen> {
  static const int _defaultOffset = 15;

  /// Önizlemede ileriye bakılan gün sayısı; haftalık tekrar bir hafta içinde
  /// mutlaka bir güne düşer.
  static const int _previewSearchDays = 8;

  late ReminderPoint _point;
  bool _isBefore = false;
  int _selectedOffset = _defaultOffset;
  String? _errorText;

  /// UI'da her zaman 7 gün seçili gösterilir; modelde "hepsi" boş kümedir.
  late Set<int> _weekdays;
  late TextEditingController _label;
  late final Map<DateTime, PrayerTime> _byDate;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _point = initial == null
        ? const ReminderPoint.prayer(PrayerType.fajr)
        : ReminderPoint.of(initial.prayerType, initial.derivedKind);
    _isBefore = (initial?.minutesBefore ?? 0) > 0;
    _selectedOffset = initial?.minutesBefore ?? _defaultOffset;
    final days = initial?.weekdays ?? const <int>{};
    _weekdays = days.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : {...days};
    _label = TextEditingController(text: initial?.label ?? '');
    _byDate = {for (final pt in widget.prayerTimes) _dateKey(pt.date): pt};
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  AppTokens get tokens => context.tokens;
  DateTime get _now => widget.clock?.call() ?? DateTime.now();
  int get _maxOffset =>
      NotificationConstants.getMaxMinutesBefore(_point.anchor);
  int get _minutes => _isBefore ? _selectedOffset : 0;
  Set<int> get _weekdaysForModel =>
      _weekdays.length == 7 ? const <int>{} : _weekdays;

  static DateTime _dateKey(DateTime d) => DateTime(d.year, d.month, d.day);

  /// [point]'in [day] günündeki sapmasız saati; veri yoksa null.
  DateTime? _pointTime(
    ReminderPoint point,
    DateTime day, {
    Set<int>? weekdays,
  }) {
    final source = _byDate[day];
    if (source == null) return null;
    return NotificationTimeRules.pointTime(
      setting: NotificationSetting(
        prayerType: point.anchor,
        derivedKind: point.derived,
        isActive: true,
        weekdays: weekdays ?? const {},
      ),
      day: source,
      prayerTimesByDate: _byDate,
    );
  }

  DateTime? _todayTime(ReminderPoint point) =>
      _pointTime(point, _dateKey(_now));

  /// Bildirimin gerçekten geleceği ilk an: bugünden başlayarak gün gün.
  DateTime? _nextFire() {
    final now = _now;
    final today = _dateKey(now);
    for (var i = 0; i < _previewSearchDays; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      final time = _pointTime(_point, day, weekdays: _weekdaysForModel);
      if (time == null) continue;
      final fire = time.subtract(Duration(minutes: _minutes));
      if (fire.isAfter(now)) return fire;
    }
    return null;
  }

  void _save() {
    if (_isBefore) {
      if (_selectedOffset <= 0) {
        setState(() => _errorText = context.l10n.remindersMinOffsetError);
        return;
      }
      if (_selectedOffset > _maxOffset) {
        setState(() {
          _errorText = context.l10n.remindersMaxOffsetError(
            formatCompactMinutes(_maxOffset, context.l10n),
          );
        });
        return;
      }
    }
    final label = _label.text.trim();
    Navigator.of(context).pop(
      NotificationDraft.fromPoint(
        _point,
        minutesBefore: _minutes,
        weekdays: _weekdaysForModel,
        label: label.isEmpty ? null : label,
      ),
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
    return value > _maxOffset ? _maxOffset : value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(
        title: widget.initial == null ? l10n.remindersNew : l10n.remindersEdit,
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              l10n.actionSave,
              style: TextStyle(color: tokens.accent),
            ),
          ),
        ],
      ),
      body: AppSurface(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _whenRow(l10n),
            _pointCard(l10n),
            ?_previewLine(l10n),
            const SizedBox(height: 16),
            _section(l10n.remindersTimeSection, _offsetSelector(l10n)),
            const SizedBox(height: 16),
            _section(l10n.remindersDaysSection, _weekdaySelector(l10n)),
            const SizedBox(height: 16),
            _section(l10n.remindersLabelSection, _labelField(l10n)),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [SectionLabel(title), const SizedBox(height: 8), child],
    );
  }

  /// Tek seçici: altı vakit ve beş hesaplanan nokta, iki grup altında. Her
  /// seçeneğin yanında bugünkü saati; hesaplananlarda kısa açıklaması.
  Widget _whenRow(AppLocalizations l10n) {
    return OptionRow<ReminderPoint>(
      label: l10n.remindersWhen,
      selected: _point,
      items: [
        for (final point in ReminderPoint.all)
          OptionItem(
            value: point,
            label: _pointName(point, l10n),
            description: _pointDescription(point, l10n),
            icon: _pointIcon(point),
            group: point.isDerived
                ? l10n.remindersDerivedGroup
                : l10n.remindersPrayerGroup,
          ),
      ],
      onChanged: (point) => setState(() {
        _point = point;
        _errorText = null;
      }),
    );
  }

  String _pointName(ReminderPoint point, AppLocalizations l10n) =>
      point.isDerived
      ? l10n.derivedName(point.derived!)
      : l10n.prayerName(point.anchor);

  String? _pointDescription(ReminderPoint point, AppLocalizations l10n) {
    final time = _todayTime(point);
    final parts = <String>[
      if (time != null) l10n.remindersTodayAt(context.formatTime(time)),
      if (point.isDerived) l10n.derivedHint(point.derived!),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  IconData _pointIcon(ReminderPoint point) => switch (point.derived) {
    null => PrayerUtils.getPrayerIcon(point.anchor),
    DerivedTimeKind.ishraq => Icons.wb_sunny_outlined,
    DerivedTimeKind.istiwa => Icons.light_mode_outlined,
    DerivedTimeKind.preMaghrib => Icons.wb_twilight_rounded,
    DerivedTimeKind.midnight => Icons.nightlight_round,
    DerivedTimeKind.lastThird => Icons.bedtime_outlined,
  };

  String _formula(DerivedTimeKind kind, AppLocalizations l10n) =>
      switch (kind) {
        DerivedTimeKind.ishraq => l10n.remindersFormulaIshraq,
        DerivedTimeKind.istiwa => l10n.remindersFormulaIstiwa,
        DerivedTimeKind.preMaghrib => l10n.remindersFormulaPreMaghrib,
        DerivedTimeKind.midnight => l10n.remindersFormulaMidnight,
        DerivedTimeKind.lastThird => l10n.remindersFormulaLastThird,
      };

  /// Seçilen noktanın açıklaması. Hesaplanan noktada formül, anlamı ve genel
  /// not; vakitte yalnız bugünkü saat.
  Widget _pointCard(AppLocalizations l10n) {
    final derived = _point.derived;
    final today = _todayTime(_point);
    final todayLine = today == null
        ? null
        : l10n.remindersTodayAt(context.formatTime(today));
    if (derived == null) {
      if (todayLine == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          todayLine,
          style: AppTypography.hint.copyWith(color: tokens.textTertiary),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formula(derived, l10n),
            style: AppTypography.rowTitle.copyWith(
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.derivedHint(derived),
            style: AppTypography.rowSubtitle.copyWith(
              color: tokens.textSecondary,
            ),
          ),
          if (todayLine != null) ...[
            const SizedBox(height: 4),
            Text(
              todayLine,
              style: AppTypography.rowSubtitle.copyWith(
                color: tokens.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            l10n.remindersDerivedExplain,
            style: AppTypography.hint.copyWith(
              color: tokens.textTertiary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// "Sıradaki: yarın 04:12" — seçimlerin somut sonucu.
  Widget? _previewLine(AppLocalizations l10n) {
    final fire = _nextFire();
    if (fire == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            Icons.notifications_active_outlined,
            size: 16,
            color: tokens.accent,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l10n.remindersNextPreview(
                reminderDayLabel(context, fire, _now),
                context.formatTime(fire),
              ),
              style: AppTypography.rowSubtitle.copyWith(
                color: tokens.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _offsetSelector(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _chip(
              label: l10n.remindersOnTimeOption,
              isSelected: !_isBefore,
              onTap: () => setState(() {
                _isBefore = false;
                _selectedOffset = 0;
                _errorText = null;
              }),
            ),
            _chip(
              label: l10n.remindersBeforeOption,
              isSelected: _isBefore,
              onTap: () => setState(() {
                _isBefore = true;
                _selectedOffset = _normalizedOffset(_selectedOffset);
                _errorText = null;
              }),
            ),
          ],
        ),
        if (_isBefore) ...[const SizedBox(height: 12), _minuteWheel(l10n)],
      ],
    );
  }

  Widget _minuteWheel(AppLocalizations l10n) {
    final maxOffset = _maxOffset;
    final hasError = _errorText != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError
              ? Theme.of(context).colorScheme.error.withValues(alpha: 0.6)
              : tokens.accent.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.remindersPickMinutes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.rowSubtitle.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${formatCompactMinutes(1, l10n)} – '
                      '${formatCompactMinutes(maxOffset, l10n)}',
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
                initialItem: (_selectedOffset - 1).clamp(0, maxOffset - 1),
              ),
              magnification: 1.1,
              squeeze: 1.05,
              useMagnifier: true,
              itemExtent: 36,
              // Seçim bandı tekerleğin *üstüne* çizilir; opak bir renk seçili
              // satırı tamamen örter. `surface` açık temada opak beyaz, bu
              // yüzden yatak rengi (mürekkep %5) kullanılıyor.
              selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                background: tokens.trackSurface,
              ),
              onSelectedItemChanged: (index) => setState(() {
                _selectedOffset = index + 1;
                _errorText = null;
              }),
              children: List.generate(
                maxOffset,
                (i) => Center(
                  child: Text(
                    formatCompactMinutes(i + 1, l10n),
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
          if (hasError) ...[
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
    );
  }

  /// Gün çipleri; alarm ekranındaki kalıpla aynı (1=Pazartesi).
  Widget _weekdaySelector(AppLocalizations l10n) {
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
                  l10n.weekdayLetter(day),
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

  Widget _labelField(AppLocalizations l10n) {
    return TextField(
      controller: _label,
      style: TextStyle(color: tokens.textPrimary),
      decoration: InputDecoration(
        hintText: l10n.reminderFridayLabel,
        hintStyle: TextStyle(color: tokens.textTertiary),
        filled: true,
        fillColor: tokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _chip({
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
              : tokens.surface,
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
}
