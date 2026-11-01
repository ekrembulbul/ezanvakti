import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/di/service_locator.dart';
import '../../core/interfaces/local_storage.dart';
import '../../core/models/notification_setting.dart';
import '../../core/models/prayer_time.dart';
import '../../core/models/quiet_window.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/device_settings_service.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/duration_formatter.dart';
import '../../features/notifications/domain/notification_time_rules.dart';
import '../../l10n/l10n_extensions.dart';
import '../utils/time_format_context.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/delete_action_button.dart';
import '../widgets/common/grouped_list.dart';
import '../widgets/common/option_picker.dart';
import '../widgets/common/row_actions_sheet.dart';
import '../widgets/common/section_label.dart';
import '../widgets/common/sliding_segment.dart';
import '../widgets/quiet/quiet_minutes_stepper.dart';
import '../widgets/quiet/quiet_timeline.dart';

/// Ezan bildirimlerinin susturulacağı vakitler ("Sessiz vakitler").
///
/// En üstte tek satırlık Cuma kaydı durur: anahtar tek dokunuşla açar ya da
/// kapatır, satıra dokununca ayrıntı paneli açılır. Altında her gün geçerli
/// diğer sessiz vakitler listelenir. Var olan kayıtlarda her değişiklik
/// anında kaydedilir — ayrı "Kaydet" yok. Yeni kayıt ise taslak olarak
/// panelde açılır ve yalnız "Ekle" ile kaydedilir.
class QuietWindowsScreen extends StatefulWidget {
  /// Sessiz vakitler değişince çağrılır; çağıran taraf yeniden planlamayı
  /// üstlenir.
  final Future<void> Function()? onChanged;

  /// "Bugün"ü belirler; testler sabit bir an verir. Verilmezse şimdiki an.
  final DateTime Function()? clock;

  const QuietWindowsScreen({super.key, this.onChanged, this.clock});

  @override
  State<QuietWindowsScreen> createState() => _QuietWindowsScreenState();
}

/// Ayrıntı panelinin neyi düzenlediği.
enum _EditorKind {
  /// Cuma kaydı: vakit seçimi ve silme yok.
  friday,

  /// Kayıtlı diğer vakit: değişiklik anında kaydedilir, silinebilir.
  existing,

  /// Henüz kaydedilmemiş yeni vakit: "Ekle" ile kaydedilir.
  draft,
}

class _QuietWindowsScreenState extends State<QuietWindowsScreen>
    with WidgetsBindingObserver {
  List<QuietWindow> _windows = [];
  bool _loading = true;

  /// Telefonu susturma (Android 10+) destekleniyor mu, Rahatsız Etme erişimi
  /// verilmiş mi. Ekran açılınca ve uygulamaya dönünce yeniden okunur.
  bool _quietSupported = false;
  bool _quietAccess = false;

  /// İzin ekranına gidilen kayıt; dönünce erişim verildiyse anahtar açılır.
  String? _pendingSilenceId;

  /// "Sessiz vakit ekle" ile açılan, henüz kaydedilmemiş kayıt.
  QuietWindow? _draft;

  /// Açık panel ekranın durumunu ayrı rotada çizer; durum değişince bu sayaç
  /// artar ve panel yeniden çizilir.
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  LocalStorage get _storage => ServiceLocator().get<LocalStorage>();

  DeviceSettingsService get _device =>
      ServiceLocator().get<DeviceSettingsService>();

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _refreshQuietAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _revision.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshQuietAccess();
  }

  /// Ekranı ve açık paneli birlikte günceller. "Geri al" ekran kapandıktan
  /// sonra da gelebilir; o durumda yalnız alan yazılır.
  void _update(VoidCallback change) {
    if (!mounted) {
      change();
      return;
    }
    setState(change);
    _revision.value++;
  }

  Future<void> _refreshQuietAccess() async {
    final supported = await _device.isQuietModeSupported();
    final access = supported && await _device.hasQuietModeAccess();
    if (!mounted) return;
    _update(() {
      _quietSupported = supported;
      _quietAccess = access;
    });
    final pending = _pendingSilenceId;
    if (pending == null) return;
    _pendingSilenceId = null;
    if (!access) return;
    final draft = _draft;
    if (draft != null && draft.id == pending) {
      _update(() => _draft = draft.copyWith(silencePhone: true));
      return;
    }
    final window = _byId(pending);
    if (window != null) await _save(window.copyWith(silencePhone: true));
  }

  /// Erişim yokken açmak kaydı değiştirmez: önce izin ekranı açılır, dönünce
  /// erişim verildiyse [_refreshQuietAccess] anahtarı açar.
  Future<void> _setSilencePhone(
    QuietWindow window,
    bool value,
    _EditorKind kind,
  ) async {
    if (value && !_quietAccess) {
      _pendingSilenceId = window.id;
      await _device.openQuietModeAccessSettings();
      return;
    }
    await _apply(window.copyWith(silencePhone: value), kind);
  }

  Future<void> _load() async {
    final windows = await _storage.getQuietWindows();
    if (!mounted) return;
    _update(() {
      _windows = windows;
      _loading = false;
    });
  }

  Future<void> _persist(List<QuietWindow> next) async {
    await _store(next);
    await _reschedule();
  }

  /// Ekrana ve depoya yazar.
  Future<void> _store(List<QuietWindow> next) async {
    _update(() => _windows = next);
    await _storage.saveQuietWindows(next);
  }

  /// Bildirim ve alarm planı sessiz vakitlere göre yeniden kurulur. Hata
  /// burada loglanır: kayıt ve "Geri al" çubuğu planlamanın sonucuna bağlı
  /// kalmaz.
  Future<void> _reschedule() async {
    try {
      await widget.onChanged?.call();
    } catch (error, stackTrace) {
      AppLogger().error('Quiet window reschedule failed', error, stackTrace);
    }
  }

  QuietWindow? _byId(String id) =>
      _windows.where((w) => w.id == id).firstOrNull;

  QuietWindow? get _friday =>
      _windows.where((w) => w.trigger == QuietTrigger.fridayDhuhr).firstOrNull;

  /// Cuma kaydı hiç yoksa panel kapalı şablonla açılır; ilk değişiklikte
  /// kayıt eklenir.
  QuietWindow get _fridayOrTemplate =>
      _friday ?? QuietWindow.fridayDefault().copyWith(isActive: false);

  List<QuietWindow> get _custom =>
      _windows.where((w) => w.trigger == QuietTrigger.prayer).toList();

  /// Kaydı kimliğiyle yerine yazar; yoksa sona ekler. Kimlikle aranır: panel
  /// bir önceki çizimden kalmış bir kopyayı tutuyor olabilir.
  Future<void> _save(QuietWindow updated) async {
    final next = [..._windows];
    final index = next.indexWhere((w) => w.id == updated.id);
    if (index < 0) {
      next.add(updated);
    } else {
      next[index] = updated;
    }
    await _persist(next);
  }

  /// Panelden gelen değişiklik: taslakta yalnız taslak güncellenir, kayıtlı
  /// vakitte anında kaydedilip yeniden planlanır.
  Future<void> _apply(QuietWindow updated, _EditorKind kind) async {
    if (kind == _EditorKind.draft) {
      _update(() => _draft = updated);
      return;
    }
    await _save(updated);
  }

  Future<void> _toggleFriday(bool enabled) =>
      _save(_fridayOrTemplate.copyWith(isActive: enabled));

  /// Yeni vakit sormadan eklenmez: taslak panelde açılır, "Ekle" ile
  /// kaydedilir. Panel başka yoldan kapanırsa taslak atılır.
  Future<void> _addCustom() async {
    _update(
      () => _draft = QuietWindow(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        trigger: QuietTrigger.prayer,
        prayerType: PrayerType.dhuhr,
        minutesBefore: 10,
        minutesAfter: 30,
      ),
    );
    final added = await _openEditor(_EditorKind.draft);
    final draft = _draft;
    _update(() => _draft = null);
    if (added == true && draft != null) {
      await _persist([..._windows, draft]);
    }
  }

  /// Onay sormadan siler; "Geri al" kaydı eski sırasına geri koyar
  /// (spec 2026-09-28 §3.3).
  Future<void> _delete(QuietWindow window) async {
    final l10n = context.l10n;
    final index = _windows.indexWhere((w) => w.id == window.id);
    if (index < 0) return;
    await _store([..._windows]..removeAt(index));
    // Çubuk planlamayı beklemez; yeniden planlama birkaç yüz ms sürebilir.
    _showUndo(l10n.quietWindowDeleted, () => _restore(window, index));
    await _reschedule();
  }

  /// Silinen kaydı aynı kimlikle, silindiği sıraya geri yazar. Güncel liste
  /// depodan okunur: çubuğa ekran kapandıktan sonra da dokunulabilir.
  Future<void> _restore(QuietWindow window, int index) async {
    final current = await _storage.getQuietWindows();
    if (current.any((w) => w.id == window.id)) return;
    final next = [...current];
    next.insert(index > next.length ? next.length : index, window);
    await _persist(next);
  }

  void _showUndo(String message, VoidCallback onUndo) {
    if (!mounted) return;
    // Onceki cubugu hemen kaldir; yeni mesaj beklemeden gorunsun.
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: context.l10n.snackUndo,
          textColor: Colors.white,
          onPressed: onUndo,
        ),
        backgroundColor: context.tokens.accent,
        // Eylemli snackbar varsayilan olarak kalici (`persist = action !=
        // null`); sure dolunca kendiliginden kalksin.
        persist: false,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        actionOverflowThreshold: 0.5,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bugünün saatleri
  // ---------------------------------------------------------------------------

  /// Planlayıcıya verilen günlük vakitler (bkz. ana sayfadaki yeniden
  /// planlama): ekrandaki saat planlanan saatle aynı veriden gelir.
  List<PrayerTime> _days(BuildContext context) {
    final appState = context.watch<AppState>();
    final today = appState.todaysPrayerTime;
    return [...appState.prayerTimes, ?today];
  }

  /// Kaydın bugünkü vakit anı; Cuma kaydında bu haftanın (bugün Cumaysa
  /// bugünün) öğle vakti. Veri yoksa `null`. Gün kuralı modelin kendi
  /// [QuietWindow.matchesPrayer]'ıyla, vakit anı bildirim planının ortak
  /// kuralıyla çözülür; ekranda ayrı vakit hesabı yapılmaz.
  DateTime? _prayerAt(QuietWindow window, List<PrayerTime> days) {
    final type = _typeOf(window);
    final now = _now;
    final today = DateTime(now.year, now.month, now.day);
    final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));
    for (final day in sorted) {
      final key = DateTime(day.date.year, day.date.month, day.date.day);
      if (key.isBefore(today)) continue;
      if (window.trigger == QuietTrigger.prayer && key != today) return null;
      if (key.difference(today).inDays >= DateTime.daysPerWeek) return null;
      final at = NotificationTimeRules.pointTime(
        setting: NotificationSetting(prayerType: type, isActive: true),
        day: day,
        prayerTimesByDate: const {},
      );
      if (at != null && window.matchesPrayer(type, at)) return at;
    }
    return null;
  }

  static PrayerType _typeOf(QuietWindow window) =>
      window.trigger == QuietTrigger.fridayDhuhr
      ? PrayerType.dhuhr
      : window.prayerType ?? PrayerType.dhuhr;

  /// "17:44 – 18:24"; veri yoksa göreli özet "10 dk önce – 30 dk sonra".
  String _rangeText(
    BuildContext context,
    QuietWindow window,
    List<PrayerTime> days,
  ) {
    final at = _prayerAt(window, days);
    if (at == null) return _durationText(window);
    return context.l10n.quietTimeRange(
      context.formatTime(at.subtract(Duration(minutes: window.minutesBefore))),
      context.formatTime(at.add(Duration(minutes: window.minutesAfter))),
    );
  }

  String _durationText(QuietWindow window) =>
      context.l10n.quietWindowDurationSummary(
        formatCompactMinutes(window.minutesBefore, context.l10n),
        formatCompactMinutes(window.minutesAfter, context.l10n),
      );

  // ---------------------------------------------------------------------------
  // Ekran
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final days = _days(context);

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
                    style: AppTypography.rowSubtitle.copyWith(
                      color: tokens.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GroupedList(children: [_fridayRow(days)]),
                  const SizedBox(height: 26),
                  SectionLabel(context.l10n.quietCustomSection),
                  const SizedBox(height: 10),
                  if (_custom.isEmpty)
                    Text(
                      context.l10n.quietNoCustom,
                      style: AppTypography.rowSubtitle.copyWith(
                        color: tokens.textSecondary,
                      ),
                    )
                  else
                    GroupedList(
                      children: [
                        for (final window in _custom) _customRow(window, days),
                      ],
                    ),
                ],
              ),
      ),
    );
  }

  /// Tek satırlık Cuma kaydı. Basılı tutma menüsü yok: Cuma silinmez.
  Widget _fridayRow(List<PrayerTime> days) {
    final tokens = context.tokens;
    final friday = _friday;
    final enabled = friday?.isActive ?? false;
    final subtitle = friday == null || !enabled
        ? context.l10n.quietOff
        : '${context.l10n.quietFridayRange(_rangeText(context, friday, days))}'
              ' · ${_fridayModeText(friday.mode)}';

    return GroupedRow(
      icon: Icons.mosque_rounded,
      title: Text(context.l10n.quietFridayTitle),
      subtitle: Text(subtitle, maxLines: 2),
      growWithContent: true,
      onTap: () => _openEditor(_EditorKind.friday),
      trailing: Switch(
        value: enabled,
        activeThumbColor: tokens.accent,
        onChanged: _toggleFriday,
      ),
    );
  }

  String _fridayModeText(QuietMode mode) => mode == QuietMode.skip
      ? context.l10n.quietFridayModeSkip
      : context.l10n.quietFridayModeSilent;

  Widget _customRow(QuietWindow window, List<PrayerTime> days) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final name = l10n.prayerName(_typeOf(window));
    final mode = window.mode == QuietMode.skip
        ? l10n.quietRowModeSkip
        : l10n.quietRowModeSilent;
    final phone = _quietSupported && window.silencePhone
        ? ' · ${l10n.quietSilencePhoneSuffix}'
        : '';

    return GroupedRow(
      // Silinince anahtarlar komşu satıra kaymasın.
      key: ValueKey(window.id),
      icon: window.mode == QuietMode.skip
          ? Icons.notifications_off_rounded
          : Icons.notifications_paused_rounded,
      title: Text(l10n.quietEveryDayTitle(name)),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _rangeText(context, window, days),
            style: TextStyle(
              color: tokens.accent,
              fontWeight: FontWeight.w600,
              fontVariations: const [FontVariation('wght', 600)],
            ),
          ),
          const SizedBox(height: 2),
          Text('$mode$phone', maxLines: 2),
        ],
      ),
      growWithContent: true,
      dimmed: !window.isActive,
      onTap: () => _openEditor(_EditorKind.existing, id: window.id),
      onLongPress: () => showRowActionsSheet(
        context,
        title: '$name · ${_durationText(window)}',
        onDelete: () => _delete(window),
      ),
      trailing: Switch(
        value: window.isActive,
        activeThumbColor: tokens.accent,
        onChanged: (value) => _save(window.copyWith(isActive: value)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Ayrıntı paneli
  // ---------------------------------------------------------------------------

  /// Paneli açar. Taslakta "Ekle"ye basılınca `true` döner.
  Future<bool?> _openEditor(_EditorKind kind, {String? id}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => ValueListenableBuilder<int>(
        valueListenable: _revision,
        builder: (sheetContext, _, _) {
          final current = switch (kind) {
            _EditorKind.friday => _fridayOrTemplate,
            _EditorKind.existing => id == null ? null : _byId(id),
            _EditorKind.draft => _draft,
          };
          if (current == null) return const SizedBox.shrink();
          return _editor(sheetContext, current, kind);
        },
      ),
    );
  }

  Widget _editor(
    BuildContext sheetContext,
    QuietWindow window,
    _EditorKind kind,
  ) {
    final tokens = sheetContext.tokens;
    final l10n = sheetContext.l10n;
    final type = _typeOf(window);
    final name = l10n.prayerName(type);
    final at = _prayerAt(window, _days(sheetContext));
    final route = ModalRoute.of(sheetContext);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              kind == _EditorKind.friday
                  ? l10n.quietFridayPanelTitle
                  : l10n.quietPanelTitle(name),
              style: AppTypography.screenTitle.copyWith(
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            QuietTimeline(
              minutesBefore: window.minutesBefore,
              minutesAfter: window.minutesAfter,
              startLabel: at == null
                  ? null
                  : sheetContext.formatTime(
                      at.subtract(Duration(minutes: window.minutesBefore)),
                    ),
              prayerLabel: at == null
                  ? name
                  : l10n.quietTimelinePrayer(name, sheetContext.formatTime(at)),
              endLabel: at == null
                  ? null
                  : sheetContext.formatTime(
                      at.add(Duration(minutes: window.minutesAfter)),
                    ),
            ),
            const SizedBox(height: 16),
            if (kind != _EditorKind.friday)
              OptionRow<PrayerType>(
                label: l10n.quietPrayerLabel,
                selected: type,
                valueLabel: l10n.prayerName,
                items: [
                  for (final value in PrayerType.values)
                    OptionItem(value: value, label: l10n.prayerName(value)),
                ],
                onChanged: (value) =>
                    _apply(window.copyWith(prayerType: value), kind),
              ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: QuietMinutesStepper(
                    label: l10n.quietMinutesBefore,
                    value: window.minutesBefore,
                    onChanged: (value) =>
                        _apply(window.copyWith(minutesBefore: value), kind),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: QuietMinutesStepper(
                    label: l10n.quietMinutesAfter,
                    value: window.minutesAfter,
                    onChanged: (value) =>
                        _apply(window.copyWith(minutesAfter: value), kind),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SectionLabel(l10n.quietModeLabel),
            const SizedBox(height: 10),
            // Bölme etiketleri tek satır; büyük metinde taşmasın.
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: SlidingSegment<QuietMode>(
                items: [
                  SegmentItem(
                    value: QuietMode.silent,
                    label: l10n.quietModeSilent,
                  ),
                  SegmentItem(value: QuietMode.skip, label: l10n.quietModeSkip),
                ],
                selected: window.mode,
                onChanged: (value) =>
                    _apply(window.copyWith(mode: value), kind),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              window.mode == QuietMode.skip
                  ? l10n.quietModeSkipHint
                  : l10n.quietModeSilentHint,
              style: AppTypography.hint.copyWith(color: tokens.textSecondary),
            ),
            if (_quietSupported) ...[
              const SizedBox(height: 14),
              _silenceRow(sheetContext, window, kind),
            ],
            if (kind == _EditorKind.draft) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Aynı karedeki ikinci dokunuş ekranı kapatmasın.
                  if (!(route?.isCurrent ?? false)) return;
                  Navigator.pop(sheetContext, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.accent,
                  foregroundColor: tokens.backgroundStops.last,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(l10n.quietAddConfirm),
              ),
            ],
            if (kind == _EditorKind.existing) ...[
              const SizedBox(height: 20),
              DeleteActionButton(l10n.quietWindowDeleteAction, () {
                // Önce panel kapanır, sonra silinir: "Geri al" çubuğu
                // listenin üstünde çıkar. Aynı karedeki ikinci dokunuş
                // ekranı kapatmasın.
                if (!(route?.isCurrent ?? false)) return;
                Navigator.pop(sheetContext);
                _delete(window);
              }),
            ],
          ],
        ),
      ),
    );
  }

  /// Android 9 ve öncesinde satır yok (çağıran gizler). Erişim kapalıyken
  /// anahtar açık kalabilir (izin sistemden geri alınabilir); alt yazı
  /// uyarıya döner ve dokununca izin ekranı açılır.
  Widget _silenceRow(
    BuildContext sheetContext,
    QuietWindow window,
    _EditorKind kind,
  ) {
    final tokens = sheetContext.tokens;
    final l10n = sheetContext.l10n;
    final missingAccess = window.silencePhone && !_quietAccess;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.quietSilencePhone,
                style: AppTypography.rowTitle.copyWith(
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: missingAccess
                    ? _device.openQuietModeAccessSettings
                    : null,
                child: Text(
                  missingAccess
                      ? l10n.quietSilencePhoneNoAccess
                      : l10n.quietSilencePhoneHint,
                  style: AppTypography.hint.copyWith(
                    color: missingAccess ? tokens.accent : tokens.textTertiary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: window.silencePhone,
          activeThumbColor: tokens.accent,
          onChanged: (value) => _setSilencePhone(window, value, kind),
        ),
      ],
    );
  }
}
