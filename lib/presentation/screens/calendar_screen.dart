import 'package:flutter/material.dart';
import '../../l10n/l10n_extensions.dart';

import '../utils/directional_icons.dart';

import '../../core/data/ramadan_periods.dart';
import '../../features/prayer_times/domain/calendar_month_repository.dart';
import '../../features/ramadan/domain/imsakiye_repository.dart';
import '../controllers/calendar_month_controller.dart';
import '../controllers/imsakiye_controller.dart';
import '../widgets/calendar/calendar_month_share_table.dart';
import '../widgets/calendar/imsakiye_view.dart';
import '../widgets/calendar/imsakiye_share_table.dart';
import '../services/widget_image_renderer.dart';
import '../services/calendar_share_service.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../../core/models/location.dart';
import '../widgets/calendar/calendar_table.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/state_widgets.dart';

class CalendarScreen extends StatefulWidget {
  final Location location;

  /// Vakit Takvimi ayları bu yükleyiciyle okur. Vakitler depodan, düzeltme
  /// okuma anında uygulanmış gelir (ADR 0004); ekran ayrı hesap yapmaz.
  final CalendarMonthLoader monthLoader;
  final ImsakiyeLoader? imsakiyeLoader;
  final int calculationRevision;

  /// Testler sabitler; varsayılan cihaz saati.
  final DateTime Function()? clock;

  const CalendarScreen({
    super.key,
    required this.location,
    required this.monthLoader,
    this.imsakiyeLoader,
    this.calculationRevision = 0,
    this.clock,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late CalendarMonthController _month;
  ImsakiyeController? _imsakiye;
  bool _showImsakiye = false;
  bool _sharing = false;

  DateTime _now() => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _month = _createMonthController();
  }

  /// Dinleyici yükleme başladıktan sonra eklenir: ilk "yükleniyor" bildirimi
  /// initState ya da didUpdateWidget içinde setState'e dönüşmesin. Build
  /// durumu doğrudan controller'dan okur.
  CalendarMonthController _createMonthController() {
    final controller = CalendarMonthController(
      loader: widget.monthLoader,
      now: _now(),
    );
    controller.updateSource(widget.location, widget.calculationRevision);
    controller.addListener(_changed);
    return controller;
  }

  @override
  void didUpdateWidget(CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.monthLoader != widget.monthLoader) {
      _month.removeListener(_changed);
      _month.dispose();
      _month = _createMonthController();
    } else {
      // Konum ya da düzeltme değiştiyse aynı ay yeniden yüklenir.
      // didUpdateWidget zaten build planlıyor; iç içe setState'ten kaçın.
      _month.removeListener(_changed);
      _month.updateSource(widget.location, widget.calculationRevision);
      _month.addListener(_changed);
    }
    if (oldWidget.imsakiyeLoader != widget.imsakiyeLoader) {
      _imsakiye?.removeListener(_changed);
      _imsakiye?.dispose();
      _imsakiye = null;
    }
    if (_showImsakiye) _ensureImsakiye();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _ensureImsakiye() {
    final loader = widget.imsakiyeLoader;
    if (loader == null) return;
    if (_imsakiye == null) {
      _imsakiye = ImsakiyeController(
        loader: loader,
        period: defaultRamadanPeriod(DateTime.now()),
      );
      _imsakiye!.updateSource(widget.location, widget.calculationRevision);
      _imsakiye!.addListener(_changed);
    } else {
      // didUpdateWidget already schedules a build; avoid a nested setState.
      _imsakiye!.removeListener(_changed);
      _imsakiye!.updateSource(widget.location, widget.calculationRevision);
      _imsakiye!.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _month.removeListener(_changed);
    _month.dispose();
    _imsakiye?.removeListener(_changed);
    _imsakiye?.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    var ok = false;
    try {
      if (_showImsakiye) {
        final controller = _imsakiye;
        if (controller == null || !controller.canShare) return;
        final period = controller.period;
        final location = widget.location;
        final caption =
            '${context.l10n.imsakiyeTitle} · ${period.hijriYear} · ${location.displayName} · ${imsakiyeDateRange(context, period)}';
        final bytes = await WidgetImageRenderer.render(
          context: context,
          child: ImsakiyeShareTable(
            location: location,
            period: period,
            days: controller.days,
          ),
        );
        ok = await CalendarShareService().sharePng(
          bytes: bytes,
          location: location,
          date: period.start,
          caption: caption,
          originRect: origin,
        );
      } else {
        final controller = _month;
        if (!controller.canShare) return;
        final month = controller.month;
        final location = widget.location;
        final caption = CalendarShareService.captionFor(
          location,
          month,
          format: context.l10n.shareCaption,
        );
        // Görünen ayın bütün günleri ekran dışında çizilir; ekrandaki
        // satırlarla sınırlı değil (spec 2026-09-28 §3.5).
        final bytes = await WidgetImageRenderer.render(
          context: context,
          child: CalendarMonthShareTable(
            location: location,
            month: month,
            days: controller.days,
          ),
        );
        ok = await CalendarShareService().sharePng(
          bytes: bytes,
          location: location,
          date: month,
          caption: caption,
          originRect: origin,
        );
      }
    } catch (error, stack) {
      CalendarShareService.logRenderFailure(error, stack);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.calendarShareFailed)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final month = _month;
    final canShare = _showImsakiye
        ? (_imsakiye?.canShare ?? false)
        : month.canShare;
    final monthLabel = calendarMonthLabel(context, month.month);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _CalendarAppBar(
        title: _showImsakiye ? l10n.imsakiyeTitle : l10n.calendarTitle,
        subtitle: _showImsakiye
            ? '${widget.location.displayName} · ${l10n.calendarDayCount(_imsakiye?.days.length ?? 0)}'
            : '${widget.location.displayName} · $monthLabel',
        // Yüklenirken ya da ay boşken paylaş düğmesi çizilmez.
        onShare: _sharing || !canShare ? null : _share,
      ),
      body: AppSurface(
        child: Padding(
          // Takvim altı saat kolonu yan yana taşıyor; sayfa payı diğer
          // ekranlardan dar tutuluyor ki kolonlara nefes kalsın.
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l10n.calendarTitle)),
                  ButtonSegment(value: true, label: Text(l10n.imsakiyeTitle)),
                ],
                selected: {_showImsakiye},
                onSelectionChanged: (selection) {
                  setState(() {
                    _showImsakiye = selection.single;
                    if (_showImsakiye) _ensureImsakiye();
                  });
                },
              ),
              const SizedBox(height: 8),
              if (!_showImsakiye) ...[
                _MonthBar(
                  label: monthLabel,
                  onPrevious: month.canGoPrevious ? month.previous : null,
                  onNext: month.canGoNext ? month.next : null,
                ),
                // Ay geçişinde eski tablo kalır; ince çizgi yeni ayın
                // yüklendiğini gösterir. Yer hep ayrılır ki tablo zıplamasın.
                SizedBox(
                  height: 2,
                  child: month.isLoading && month.days.isNotEmpty
                      ? LinearProgressIndicator(
                          minHeight: 2,
                          color: context.tokens.accent,
                          backgroundColor: Colors.transparent,
                        )
                      : null,
                ),
              ],
              Expanded(
                child: _showImsakiye
                    ? (_imsakiye == null
                          ? ErrorState(message: l10n.imsakiyeLoadFailed)
                          : ImsakiyeView(controller: _imsakiye!))
                    : _buildMonthBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthBody() {
    final month = _month;
    final l10n = context.l10n;
    final days = month.days;
    if (days.isNotEmpty) {
      // Tablo gösterdiği günlerin ayıyla anahtarlanır, seçili ayla değil:
      // ay değişirken eski tablo yükleme boyunca yerinde durur (başa
      // atlamaz); yeni ay gelince yeni tablo kurulur ve başlangıç konumu
      // (bugün ya da en üst) yeniden hesaplanır.
      final shownMonth = DateTime(days.first.date.year, days.first.date.month);
      return CalendarTable(key: ValueKey(shownMonth), days: days, now: _now());
    }
    if (month.error != null && !month.isLoading) {
      return ErrorState(
        message: l10n.offlineFetchFailed,
        onRetry: month.refresh,
      );
    }
    if (month.isUnavailable) {
      return EmptyState(
        icon: Icons.calendar_month_outlined,
        message: l10n.calendarMonthUnavailable,
      );
    }
    return LoadingState(message: l10n.calendarLoading);
  }
}

/// Takvimde segmentin altındaki ay çubuğu: önceki ay · ay adı · sonraki ay.
class _MonthBar extends StatelessWidget {
  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _MonthBar({required this.label, this.onPrevious, this.onNext});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        // Chevron ikonları matchTextDirection taşır: Icon RTL'de kendini
        // aynalar ve Row "önceki"yi sağa koyar. directional_icons'taki gibi
        // ayrıca ikon değiştirmek yönü iki kez çevirirdi.
        _arrow(
          context,
          key: const Key('calendar-previous-month'),
          icon: Icons.chevron_left_rounded,
          tooltip: context.l10n.calendarPreviousMonth,
          onPressed: onPrevious,
        ),
        Expanded(
          child: Center(
            // Dar ekran ve büyük metinde ay adı küçülür; oklar sabit kalır.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                key: const Key('calendar-month-label'),
                maxLines: 1,
                style: AppTypography.rowTitle.copyWith(
                  color: tokens.textPrimary,
                ),
              ),
            ),
          ),
        ),
        _arrow(
          context,
          key: const Key('calendar-next-month'),
          icon: Icons.chevron_right_rounded,
          tooltip: context.l10n.calendarNextMonth,
          onPressed: onNext,
        ),
      ],
    );
  }

  /// Geri düğmesiyle aynı 34 pt yüzey kutusu (8 + 18 + 8); sınırda pasif.
  Widget _arrow(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    final tokens = context.tokens;
    return IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onPressed == null ? tokens.textTertiary : tokens.textPrimary,
        ),
      ),
    );
  }
}

class _CalendarAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;

  /// Veri yokken null; düğme o zaman çizilmez.
  final VoidCallback? onShare;

  const _CalendarAppBar({
    required this.title,
    required this.subtitle,
    this.onShare,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      // Vakitler ve Araçlar'dan push ile açılır; geri oku diğer sayfalarla
      // aynı biçimde (SimpleAppBar).
      leading: Navigator.of(context).canPop()
          ? IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  context.backArrow,
                  size: 18,
                  color: tokens.textPrimary,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      title: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: AppTypography.screenTitle.copyWith(
                color: tokens.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: AppTypography.hint.copyWith(color: tokens.textTertiary),
            ),
          ],
        ),
      ),
      centerTitle: true,
      actions: [
        if (onShare != null)
          IconButton(
            onPressed: onShare,
            icon: const Icon(Icons.ios_share_rounded),
            color: tokens.textSecondary,
            tooltip: context.l10n.calendarShare,
          ),
      ],
    );
  }
}
