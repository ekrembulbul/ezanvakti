import 'package:flutter/material.dart';
import '../../l10n/l10n_extensions.dart';
import 'package:flutter/rendering.dart';

import '../../core/data/ramadan_periods.dart';
import '../../features/ramadan/domain/imsakiye_repository.dart';
import '../controllers/imsakiye_controller.dart';
import '../widgets/calendar/imsakiye_view.dart';
import '../widgets/calendar/imsakiye_share_table.dart';
import '../services/widget_image_renderer.dart';
import '../services/calendar_share_service.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../../core/models/prayer_time.dart';
import '../../core/models/location.dart';
import '../widgets/calendar/calendar_table.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/state_widgets.dart';

class CalendarScreen extends StatefulWidget {
  final Location location;
  final List<PrayerTime> prayerTimes;
  final VoidCallback? onRefresh;
  final bool isLoading;
  final String? errorMessage;
  final ImsakiyeLoader? imsakiyeLoader;
  final int calculationRevision;

  const CalendarScreen({
    super.key,
    required this.location,
    required this.prayerTimes,
    this.onRefresh,
    this.isLoading = false,
    this.errorMessage,
    this.imsakiyeLoader,
    this.calculationRevision = 0,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  /// Paylaşılacak alanı işaretler: tablo bu sınırın içinde çizilir.
  final GlobalKey _tableBoundaryKey = GlobalKey();
  ImsakiyeController? _imsakiye;
  bool _showImsakiye = false;
  bool _sharing = false;

  @override
  void didUpdateWidget(CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
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
        final boundary =
            _tableBoundaryKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;
        final l10n = context.l10n;
        ok = await CalendarShareService().shareTable(
          boundary: boundary,
          location: widget.location,
          date: widget.prayerTimes.isEmpty
              ? DateTime.now()
              : widget.prayerTimes.first.date,
          captionFormat: l10n.shareCaption,
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _CalendarAppBar(
        location: widget.location,
        dayCount: _showImsakiye
            ? (_imsakiye?.days.length ?? 0)
            : widget.prayerTimes.length,
        title: _showImsakiye
            ? context.l10n.imsakiyeTitle
            : context.l10n.calendarTitle,
        onShare:
            _sharing ||
                (_showImsakiye
                    ? !(_imsakiye?.canShare ?? false)
                    : widget.prayerTimes.isEmpty)
            ? null
            : _share,
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
                  ButtonSegment(
                    value: false,
                    label: Text(context.l10n.calendarTitle),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(context.l10n.imsakiyeTitle),
                  ),
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
              Expanded(
                child: _showImsakiye
                    ? (_imsakiye == null
                          ? ErrorState(message: context.l10n.imsakiyeLoadFailed)
                          : ImsakiyeView(controller: _imsakiye!))
                    : _buildBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (widget.isLoading) {
      return LoadingState(message: context.l10n.calendarLoading);
    }

    if (widget.errorMessage != null) {
      return ErrorState(
        message: widget.errorMessage!,
        onRetry: widget.onRefresh,
      );
    }

    if (widget.prayerTimes.isEmpty) {
      return EmptyState(
        icon: Icons.calendar_month_outlined,
        message: context.l10n.calendarEmpty,
      );
    }

    // Liste en bastan gosterilir; bugune otomatik kaydirma yok. Veri zaten
    // bugunden basliyor ve kaydirma, acilista icerigin altindan kaymasi gibi
    // duruyordu.
    // Paylaşılan görüntü uygulamadaki tabloyla birebir aynı olsun diye
    // ekrandaki widget'ın kendisi yakalanıyor, ayrı bir çizim yapılmıyor.
    return RepaintBoundary(
      key: _tableBoundaryKey,
      child: CalendarTable(days: widget.prayerTimes, now: DateTime.now()),
    );
  }
}

class _CalendarAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Location location;
  final int dayCount;
  final String title;

  /// Veri yokken null; düğme o zaman çizilmez.
  final VoidCallback? onShare;

  const _CalendarAppBar({
    required this.location,
    required this.dayCount,
    required this.title,
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
      // Sekme olarak barindirildigi icin geri oku yok.
      automaticallyImplyLeading: false,
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
              '${location.displayName} · ${context.l10n.calendarDayCount(dayCount)}',
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
