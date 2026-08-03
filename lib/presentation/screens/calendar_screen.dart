import 'package:flutter/material.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../../core/models/prayer_time.dart';
import '../../core/models/location.dart';
import '../widgets/calendar/calendar_table.dart';
import '../widgets/common/app_bar_widgets.dart';
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
  final ScrollController _scrollController = ScrollController();
  int? _todayIndex;

  @override
  void initState() {
    super.initState();
    _todayIndex = _findTodayIndex();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int? _findTodayIndex() {
    final now = DateTime.now();
    for (var i = 0; i < widget.prayerTimes.length; i++) {
      final date = widget.prayerTimes[i].date;
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        return i;
      }
    }
    return null;
  }

  /// Satır yüksekliği sabit ([kCalendarRowHeight]) olduğu için hedef ofset
  /// doğrudan hesaplanabiliyor; `GlobalKey` + `ensureVisible` gerekmiyor.
  void _scrollToToday() {
    final index = _todayIndex;
    if (index == null || !_scrollController.hasClients) return;

    final target = (index * kCalendarRowHeight).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _CalendarAppBar(
        location: widget.location,
        dayCount: widget.prayerTimes.length,
        showTodayButton: _todayIndex != null,
        onTodayTap: _scrollToToday,
      ),
      body: AppSurface(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (widget.isLoading) {
      return const LoadingState(message: 'Takvim yükleniyor...');
    }

    if (widget.errorMessage != null) {
      return ErrorState(
        message: widget.errorMessage!,
        onRetry: widget.onRefresh,
      );
    }

    if (widget.prayerTimes.isEmpty) {
      return const EmptyState(
        icon: Icons.calendar_month_outlined,
        message: 'Takvim verisi bulunamadı',
      );
    }

    return CalendarTable(
      days: widget.prayerTimes,
      now: DateTime.now(),
      controller: _scrollController,
    );
  }
}

class _CalendarAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Location location;
  final int dayCount;
  final bool showTodayButton;
  final VoidCallback? onTodayTap;

  const _CalendarAppBar({
    required this.location,
    required this.dayCount,
    required this.showTodayButton,
    this.onTodayTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: tokens.textPrimary,
          ),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        children: [
          Text(
            'Vakit Takvimi',
            style: AppTypography.screenTitle.copyWith(
              color: tokens.textPrimary,
            ),
          ),
          Text(
            '${location.displayName} · $dayCount gün',
            style: AppTypography.hint.copyWith(color: tokens.textTertiary),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        if (showTodayButton)
          AppBarActionButton(
            icon: Icons.today_rounded,
            onTap: onTodayTap ?? () {},
            tooltip: 'Bugüne Git',
            highlighted: true,
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}
