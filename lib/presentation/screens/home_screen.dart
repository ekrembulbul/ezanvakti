import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/location.dart';
import '../../core/models/prayer_time.dart';
import '../../core/utils/prayer_utils.dart';
import '../../features/daily_content/domain/daily_content.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/state_widgets.dart';
import '../../features/ramadan/domain/ramadan_countdown.dart';
import '../../features/prayer_times/domain/kerahat_times.dart';
import '../../l10n/l10n_extensions.dart';
import '../widgets/home/countdown_hero.dart';
import '../widgets/home/daily_content_section.dart';
import '../widgets/home/day_ruler.dart';
import '../widgets/home/home_top_bar.dart';
import '../widgets/home/kerahat_details_sheet.dart';
import '../widgets/home/prayer_grid.dart';

class HomeScreen extends StatefulWidget {
  /// Ramazan modu açık mı; sayaç ve başlıklar buna göre değişir.
  final bool ramadanActive;

  final Location location;
  final PrayerTime? todaysPrayerTime;
  final PrayerTime? tomorrowsPrayerTime;
  final DateTime? lastUpdateTime;
  final String dataSource;
  final VoidCallback? onSettingsTap;

  /// Üst çubuktaki takvim kısayolu; null ise düğme çizilmez.
  final VoidCallback? onCalendarTap;

  final VoidCallback? onRefresh;
  final VoidCallback? onGpsRefresh;
  final VoidCallback? onLocationTap;

  final bool isLoading;

  /// Arka planda yenileme sürüyor. Ekrandaki vakitler yerinde kalır, üst
  /// çubukta ince bir gösterge çizilir.
  final bool isRefreshing;

  final String? errorMessage;

  /// Günün ayeti, hadisi ve duası; yalnız Türkçe arayüzde gösterilir.
  final DailyContent? dailyContent;

  const HomeScreen({
    this.ramadanActive = false,
    super.key,
    required this.location,
    this.todaysPrayerTime,
    this.tomorrowsPrayerTime,
    this.lastUpdateTime,
    this.dataSource = 'Aladhan API',
    this.onSettingsTap,
    this.onCalendarTap,
    this.onRefresh,
    this.onGpsRefresh,
    this.onLocationTap,
    this.isLoading = false,
    this.isRefreshing = false,
    this.errorMessage,
    this.dailyContent,
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = widget.todaysPrayerTime;
    final kerahatIntervals =
        today != null && DateUtils.isSameDay(today.date, now)
        ? KerahatTimes.forDay(today)
        : const <KerahatInterval>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppSurface(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              HomeTopBar(
                locationName: widget.location.displayName,
                isGpsLocation: widget.location.type == LocationType.gps,
                onLocationTap: widget.onLocationTap,
                onSettingsTap: widget.onSettingsTap ?? () {},
                onCalendarTap: widget.onCalendarTap,
                onKerahatTap:
                    kerahatIntervals.isEmpty ||
                        widget.isLoading ||
                        widget.errorMessage != null
                    ? null
                    : () => showKerahatDetails(
                        context,
                        intervals: kerahatIntervals,
                      ),
                isRefreshing: widget.isRefreshing,
              ),
              Expanded(child: _buildBody(now, kerahatIntervals)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(DateTime now, List<KerahatInterval> kerahatIntervals) {
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
      return EmptyState(
        icon: Icons.hourglass_empty_rounded,
        message: context.l10n.offlineNoData,
      );
    }

    // Ramazan'da sayaç sıradaki vakte değil iftara/sahura sayar: kullanıcının
    // o ay boyunca beklediği bilgi bu.
    final ramadan = widget.ramadanActive
        ? RamadanCountdown.resolve(
            now: now,
            today: today,
            tomorrow: widget.tomorrowsPrayerTime,
          )
        : null;

    final nextTime =
        ramadan?.time ??
        PrayerUtils.getNextPrayerTime(today, widget.tomorrowsPrayerTime);
    final nextType = PrayerUtils.getNextPrayerType(today);
    final nextName = ramadan == null
        ? (nextType == null ? null : context.l10n.prayerName(nextType))
        : (ramadan.kind == RamadanCountdownKind.iftar
              ? context.l10n.ramadanIftarCountdown
              : context.l10n.ramadanSuhoorCountdown);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 8),
          HomeDateLine(date: today.date, hijri: today.hijri),
          const SizedBox(height: 20),
          if (nextTime != null && nextName != null)
            CountdownHero(
              nextPrayerTime: nextTime,
              nextPrayerName: nextName,
              kerahatIntervals: kerahatIntervals,
            ),
          const SizedBox(height: 26),
          DayRuler(
            prayerTime: today,
            now: now,
            kerahatIntervals: kerahatIntervals,
          ),
          const SizedBox(height: 24),
          PrayerGrid(
            prayerTime: today,
            now: now,
            currentPrayer: PrayerUtils.getCurrentPrayer(today),
          ),
          const SizedBox(height: 20),
          if (widget.dailyContent case final content?
              when Localizations.localeOf(context).languageCode == 'tr') ...[
            DailyContentSection(content: content),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}
