import 'package:flutter/material.dart';
import '../../l10n/l10n_extensions.dart';
import 'package:flutter/rendering.dart';

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

  const CalendarScreen({
    super.key,
    required this.location,
    required this.prayerTimes,
    this.onRefresh,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  /// Paylaşılacak alanı işaretler: tablo bu sınırın içinde çizilir.
  final GlobalKey _tableBoundaryKey = GlobalKey();

  Future<void> _share() async {
    final boundary =
        _tableBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    final l10n = context.l10n;
    final ok = await CalendarShareService().shareTable(
      boundary: boundary,
      location: widget.location,
      date: widget.prayerTimes.isEmpty
          ? DateTime.now()
          : widget.prayerTimes.first.date,
      captionFormat: l10n.shareCaption,
    );
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
        dayCount: widget.prayerTimes.length,
        onShare: widget.prayerTimes.isEmpty ? null : _share,
      ),
      body: AppSurface(
        child: Padding(
          // Takvim altı saat kolonu yan yana taşıyor; sayfa payı diğer
          // ekranlardan dar tutuluyor ki kolonlara nefes kalsın.
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _buildBody(),
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

  /// Veri yokken null; düğme o zaman çizilmez.
  final VoidCallback? onShare;

  const _CalendarAppBar({
    required this.location,
    required this.dayCount,
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
      title: Column(
        children: [
          Text(
            context.l10n.calendarTitle,
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
