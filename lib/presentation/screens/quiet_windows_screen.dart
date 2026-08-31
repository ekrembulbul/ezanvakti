import 'package:flutter/material.dart';
import '../../l10n/l10n_extensions.dart';

import '../../core/di/service_locator.dart';
import '../../core/interfaces/local_storage.dart';
import '../../core/models/notification_setting.dart' show PrayerType;
import '../../core/models/quiet_window.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/grouped_list.dart';
import '../widgets/common/option_picker.dart';
import '../widgets/common/section_label.dart';
import '../widgets/common/swipe_to_delete.dart';

/// Bildirimlerin susturulacağı zaman aralıkları.
///
/// Cuma penceresi hazır şablon olarak en üstte durur; altına vakit bazlı
/// özel pencereler eklenir. Kaydetme anında yapılır — ayrı "Kaydet" yok,
/// çünkü her satır tek başına anlamlı.
class QuietWindowsScreen extends StatefulWidget {
  /// Pencereler değişince çağrılır; çağıran taraf yeniden planlamayı üstlenir.
  final Future<void> Function()? onChanged;

  const QuietWindowsScreen({super.key, this.onChanged});

  @override
  State<QuietWindowsScreen> createState() => _QuietWindowsScreenState();
}

class _QuietWindowsScreenState extends State<QuietWindowsScreen> {
  List<QuietWindow> _windows = [];
  bool _loading = true;

  LocalStorage get _storage => ServiceLocator().get<LocalStorage>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final windows = await _storage.getQuietWindows();
    if (!mounted) return;
    setState(() {
      _windows = windows;
      _loading = false;
    });
  }

  Future<void> _persist(List<QuietWindow> next) async {
    setState(() => _windows = next);
    await _storage.saveQuietWindows(next);
    await widget.onChanged?.call();
  }

  QuietWindow? get _friday =>
      _windows.where((w) => w.trigger == QuietTrigger.fridayDhuhr).firstOrNull;

  List<QuietWindow> get _custom =>
      _windows.where((w) => w.trigger == QuietTrigger.prayer).toList();

  Future<void> _toggleFriday(bool enabled) async {
    final next = [..._windows];
    final existing = _friday;
    if (existing == null) {
      next.add(QuietWindow.fridayDefault().copyWith(isActive: enabled));
    } else {
      next[next.indexOf(existing)] = existing.copyWith(isActive: enabled);
    }
    await _persist(next);
  }

  Future<void> _updateWindow(QuietWindow window, QuietWindow updated) async {
    final next = [..._windows];
    next[next.indexOf(window)] = updated;
    await _persist(next);
  }

  Future<void> _addCustom() async {
    final next = [
      ..._windows,
      QuietWindow(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        trigger: QuietTrigger.prayer,
        prayerType: PrayerType.dhuhr,
        minutesBefore: 10,
        minutesAfter: 30,
      ),
    ];
    await _persist(next);
  }

  Future<void> _delete(QuietWindow window) async {
    await _persist(_windows.where((w) => w.id != window.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(title: context.l10n.quietTitle),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustom,
        backgroundColor: tokens.accent,
        icon: const Icon(Icons.add_rounded),
        label: Text(context.l10n.quietAddWindow),
      ),
      body: AppSurface(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  Text(
                    context.l10n.quietIntro,
                    style: AppTypography.hint.copyWith(
                      color: tokens.textTertiary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SectionLabel(context.l10n.quietFridaySection),
                  const SizedBox(height: 10),
                  _fridayCard(),
                  const SizedBox(height: 26),
                  SectionLabel(context.l10n.quietCustomSection),
                  const SizedBox(height: 10),
                  if (_custom.isEmpty)
                    Text(
                      context.l10n.quietNoCustom,
                      style: AppTypography.rowSubtitle.copyWith(
                        color: tokens.textTertiary,
                      ),
                    )
                  else
                    GroupedList(
                      children: [
                        for (final window in _custom) _customRow(window),
                      ],
                    ),
                ],
              ),
      ),
    );
  }

  Widget _fridayCard() {
    final tokens = context.tokens;
    final friday = _friday;
    final enabled = friday?.isActive ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.quietFridayTitle,
                      style: AppTypography.rowTitle.copyWith(
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.quietFridayHint,
                      style: AppTypography.hint.copyWith(
                        color: tokens.textTertiary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                activeThumbColor: tokens.accent,
                onChanged: _toggleFriday,
              ),
            ],
          ),
          if (friday != null && enabled) ...[
            const SizedBox(height: 8),
            Divider(height: 1, thickness: 1, color: tokens.divider),
            const SizedBox(height: 8),
            _rangeRow(friday),
            _modeRow(friday),
          ],
        ],
      ),
    );
  }

  Widget _customRow(QuietWindow window) {
    final tokens = context.tokens;
    final name = context.l10n.prayerName(
      window.prayerType ?? PrayerType.dhuhr,
    );

    return SwipeToDelete(
      itemKey: ValueKey(window.id),
      onDelete: () => _delete(window),
      child: GroupedRow(
        icon: Icons.notifications_off_rounded,
        title: Text(name),
        subtitle: Text(
          '${context.l10n.quietWindowSummary(window.minutesBefore, window.minutesAfter)} · '
          '${window.mode == QuietMode.skip ? context.l10n.quietModeSkip : context.l10n.quietModeSilent}',
        ),
        dimmed: !window.isActive,
        onTap: () => _editCustom(window),
        trailing: Switch(
          value: window.isActive,
          activeThumbColor: tokens.accent,
          onChanged: (value) =>
              _updateWindow(window, window.copyWith(isActive: value)),
        ),
      ),
    );
  }

  Future<void> _editCustom(QuietWindow window) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final current =
              _windows.where((w) => w.id == window.id).firstOrNull ?? window;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OptionRow<PrayerType>(
                    label: context.l10n.quietPrayerLabel,
                    selected: current.prayerType ?? PrayerType.dhuhr,
                    valueLabel: context.l10n.prayerName,
                    items: [
                      for (final type in PrayerType.values)
                        OptionItem(
                          value: type,
                          label: context.l10n.prayerName(type),
                        ),
                    ],
                    onChanged: (value) async {
                      await _updateWindow(
                        current,
                        current.copyWith(prayerType: value),
                      );
                      setSheetState(() {});
                    },
                  ),
                  _rangeRow(current, onChanged: () => setSheetState(() {})),
                  _modeRow(current, onChanged: () => setSheetState(() {})),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _rangeRow(QuietWindow window, {VoidCallback? onChanged}) {
    return Column(
      children: [
        _stepperRow(
          context.l10n.quietMinutesBefore,
          window.minutesBefore,
          (value) async {
            await _updateWindow(window, window.copyWith(minutesBefore: value));
            onChanged?.call();
          },
        ),
        _stepperRow(
          context.l10n.quietMinutesAfter,
          window.minutesAfter,
          (value) async {
            await _updateWindow(window, window.copyWith(minutesAfter: value));
            onChanged?.call();
          },
        ),
      ],
    );
  }

  /// 5'er dakikalık adımlar; 0–180 dk arası. Bir namaz penceresi için üç saat
  /// fazlasıyla yeterli, ötesi kazara tüm günü susturmak olurdu.
  Widget _stepperRow(String label, int value, ValueChanged<int> onChanged) {
    final tokens = context.tokens;
    const step = 5;
    const maxMinutes = 180;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.rowSubtitle.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ),
          IconButton(
            onPressed: value >= step ? () => onChanged(value - step) : null,
            icon: const Icon(Icons.remove_rounded, size: 20),
            color: tokens.accent,
            disabledColor: tokens.textTertiary,
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 56,
            child: Text(
              '$value dk',
              textAlign: TextAlign.center,
              style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
            ),
          ),
          IconButton(
            onPressed: value <= maxMinutes - step
                ? () => onChanged(value + step)
                : null,
            icon: const Icon(Icons.add_rounded, size: 20),
            color: tokens.accent,
            disabledColor: tokens.textTertiary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _modeRow(QuietWindow window, {VoidCallback? onChanged}) {
    return OptionRow<QuietMode>(
      label: context.l10n.quietModeLabel,
      selected: window.mode,
      valueLabel: (mode) => mode == QuietMode.skip
          ? context.l10n.quietModeSkip
          : context.l10n.quietModeSilent,
      items: [
        OptionItem(
          value: QuietMode.silent,
          label: context.l10n.quietModeSilent,
          description: context.l10n.quietModeSilentHint,
          icon: Icons.notifications_paused_rounded,
        ),
        OptionItem(
          value: QuietMode.skip,
          label: context.l10n.quietModeSkip,
          description: context.l10n.quietModeSkipHint,
          icon: Icons.notifications_off_rounded,
        ),
      ],
      onChanged: (value) async {
        await _updateWindow(window, window.copyWith(mode: value));
        onChanged?.call();
      },
    );
  }
}
