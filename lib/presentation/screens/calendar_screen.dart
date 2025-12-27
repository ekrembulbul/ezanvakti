import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/prayer_time.dart';
import '../../core/models/location.dart';
import '../widgets/calendar/calendar_day_card.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToToday() {
    if (_todayIndex != null && _scrollController.hasClients) {
      const itemHeight = 180.0;
      final offset = (_todayIndex! * itemHeight) - 100;
      _scrollController.animateTo(
        offset.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    for (int i = 0; i < widget.prayerTimes.length; i++) {
      if (_isToday(widget.prayerTimes[i].date)) {
        _todayIndex = i;
        break;
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _CalendarAppBar(
        location: widget.location,
        showTodayButton: _todayIndex != null,
        onTodayTap: _scrollToToday,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.nightGradient),
        child: SafeArea(child: _buildBody()),
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

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh?.call(),
      color: AppTheme.gold,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: widget.prayerTimes.length,
        itemBuilder: (context, index) {
          final prayerTime = widget.prayerTimes[index];
          return CalendarDayCard(
            prayerTime: prayerTime,
            isToday: _isToday(prayerTime.date),
          );
        },
      ),
    );
  }
}

class _CalendarAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Location location;
  final bool showTodayButton;
  final VoidCallback? onTodayTap;

  const _CalendarAppBar({
    required this.location,
    required this.showTodayButton,
    this.onTodayTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        children: [
          const Text(
            'Vakit Takvimi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Text(
            '${location.district}, ${location.province}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        if (showTodayButton)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.today_rounded,
                size: 18,
                color: AppTheme.gold,
              ),
            ),
            onPressed: onTodayTap,
            tooltip: 'Bugüne Git',
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}
