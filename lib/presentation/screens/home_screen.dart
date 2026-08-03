import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/location.dart';
import '../../core/models/prayer_time.dart';
import '../../core/utils/prayer_utils.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/state_widgets.dart';
import '../widgets/home/countdown_hero.dart';
import '../widgets/home/day_ruler.dart';
import '../widgets/home/home_menu_sheet.dart';
import '../widgets/home/home_top_bar.dart';
import '../widgets/home/prayer_grid.dart';
import '../widgets/home/tomorrow_strip.dart';
import '../widgets/home/upcoming_card.dart';

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
  final VoidCallback? onLocationTap;
  final bool isLoading;

  /// Arka planda yenileme sürüyor. Ekrandaki vakitler yerinde kalır, üst
  /// çubukta ince bir gösterge çizilir.
  final bool isRefreshing;

  final String? errorMessage;

  const HomeScreen({
    super.key,
    required this.location,
    this.todaysPrayerTime,
    this.tomorrowsPrayerTime,
    this.lastUpdateTime,
    this.dataSource = 'Aladhan API',
    this.onCalendarTap,
    this.onSettingsTap,
    this.onNotificationSettingsTap,
    this.onRefresh,
    this.onGpsRefresh,
    this.onLocationTap,
    this.isLoading = false,
    this.isRefreshing = false,
    this.errorMessage,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Aktif vakit vurgusu ve cetvel göstergesi için kaba yenileme; saniyelik
    // tik CountdownHero'nun kendi içinde.
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _openMenu() {
    showHomeMenu(
      context,
      onCalendar: widget.onCalendarTap,
      onNotifications: widget.onNotificationSettingsTap,
      onSettings: widget.onSettingsTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppSurface(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              HomeTopBar(
                locationName: widget.location.displayName,
                onLocationTap: widget.onLocationTap,
                onMenuTap: _openMenu,
                isRefreshing: widget.isRefreshing,
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (widget.isLoading) return const LoadingState();

    if (widget.errorMessage != null) {
      return ErrorState(
        message: widget.errorMessage!,
        onRetry: widget.onRefresh,
      );
    }

    final today = widget.todaysPrayerTime;
    if (today == null) {
      // İlk yüklemede veri henüz gelmediyse boş ekran yerine yükleniyor göster.
      if (widget.lastUpdateTime == null) return const LoadingState();
      return const EmptyState(
        icon: Icons.hourglass_empty_rounded,
        message: 'Veri bulunamadı',
      );
    }

    final now = DateTime.now();
    final nextTime = PrayerUtils.getNextPrayerTime(
      today,
      widget.tomorrowsPrayerTime,
    );
    final nextName = PrayerUtils.getNextPrayerName(today);
    final tomorrow = widget.tomorrowsPrayerTime;

    return Column(
      children: [
        const SizedBox(height: 8),
        HomeDateLine(date: today.date),
        const SizedBox(height: 20),
        if (nextTime != null && nextName != null)
          CountdownHero(nextPrayerTime: nextTime, nextPrayerName: nextName),
        const SizedBox(height: 26),
        DayRuler(prayerTime: today, now: now),
        const SizedBox(height: 24),
        PrayerGrid(
          prayerTime: today,
          now: now,
          currentPrayer: PrayerUtils.getCurrentPrayer(today),
        ),
        const SizedBox(height: 24),
        if (tomorrow != null) ...[
          TomorrowStrip(
            tomorrow: tomorrow,
            onCalendarTap: widget.onCalendarTap ?? () {},
          ),
          const SizedBox(height: 20),
        ],
        UpcomingCard(onSeeAll: widget.onNotificationSettingsTap ?? () {}),
        // Artan boşluk altta toplanır; içerik yukarı yaslı kalır.
        const Spacer(),
      ],
    );
  }
}
