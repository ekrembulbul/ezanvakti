import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/prayer_time.dart';
import '../../core/models/location.dart';
import '../../core/utils/prayer_utils.dart';
import '../widgets/home/countdown_card.dart';
import '../widgets/home/prayer_times_card.dart';
import '../widgets/home/quick_action_card.dart';
import '../widgets/home/home_date_card.dart';
import '../widgets/common/state_widgets.dart';

class HomeScreen extends StatefulWidget {
  final Location location;
  final PrayerTime? todaysPrayerTime;
  final PrayerTime? tomorrowsPrayerTime;
  final DateTime? lastUpdateTime;
  final String dataSource;
  final VoidCallback? onCalendarTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onNotificationSettingsTap;
  final VoidCallback? onRefresh;
  final VoidCallback? onGpsRefresh;
  final bool isLoading;
  final String? errorMessage;

  const HomeScreen({
    super.key,
    required this.location,
    this.todaysPrayerTime,
    this.tomorrowsPrayerTime,
    this.lastUpdateTime,
    this.dataSource = 'Diyanet (Awqat Salah API)',
    this.onCalendarTap,
    this.onSettingsTap,
    this.onNotificationSettingsTap,
    this.onRefresh,
    this.onGpsRefresh,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _HomeAppBar(
        location: widget.location,
        onGpsRefresh: widget.onGpsRefresh,
        onNotificationsTap: widget.onNotificationSettingsTap,
        onSettingsTap: widget.onSettingsTap,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.nightGradient),
        child: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (widget.isLoading) {
      return const LoadingState();
    }

    if (widget.errorMessage != null) {
      return ErrorState(
        message: widget.errorMessage!,
        onRetry: widget.onRefresh,
      );
    }

    if (widget.todaysPrayerTime == null) {
      return const EmptyState(
        icon: Icons.hourglass_empty_rounded,
        message: 'Veri bulunamadı',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh?.call(),
      color: AppTheme.gold,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              HomeDateCard(date: widget.todaysPrayerTime!.date),
              const SizedBox(height: 24),
              _buildCountdown(),
              const SizedBox(height: 28),
              PrayerTimesCard(
                prayerTime: widget.todaysPrayerTime!,
                currentPrayer: PrayerUtils.getCurrentPrayer(
                  widget.todaysPrayerTime!,
                ),
                onCalendarTap: widget.onCalendarTap,
              ),
              const SizedBox(height: 20),
              QuickActionsRow(
                onCalendarTap: widget.onCalendarTap,
                onNotificationsTap: widget.onNotificationSettingsTap,
                onSettingsTap: widget.onSettingsTap,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdown() {
    final nextPrayerTime = PrayerUtils.getNextPrayerTime(
      widget.todaysPrayerTime,
      widget.tomorrowsPrayerTime,
    );
    final nextPrayerName = PrayerUtils.getNextPrayerName(
      widget.todaysPrayerTime,
    );

    if (nextPrayerTime == null || nextPrayerName == null) {
      return const SizedBox.shrink();
    }

    return CountdownCard(
      nextPrayerTime: nextPrayerTime,
      nextPrayerName: nextPrayerName,
      pulseAnimation: _pulseAnimation,
    );
  }
}

class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Location location;
  final VoidCallback? onGpsRefresh;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onSettingsTap;

  const _HomeAppBar({
    required this.location,
    this.onGpsRefresh,
    this.onNotificationsTap,
    this.onSettingsTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              location.type == LocationType.gps
                  ? Icons.my_location_rounded
                  : Icons.location_on_rounded,
              color: AppTheme.gold,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                location.district,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                location.province,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (location.type == LocationType.gps && onGpsRefresh != null)
          _AppBarAction(
            icon: Icons.gps_fixed_rounded,
            onTap: onGpsRefresh!,
            tooltip: 'GPS Yenile',
          ),
        _AppBarAction(
          icon: Icons.notifications_rounded,
          onTap: onNotificationsTap ?? () {},
          tooltip: 'Bildirimler',
        ),
        _AppBarAction(
          icon: Icons.settings_rounded,
          onTap: onSettingsTap ?? () {},
          tooltip: 'Ayarlar',
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _AppBarAction({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Tooltip(
            message: tooltip ?? '',
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
