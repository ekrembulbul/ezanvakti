import '../../core/models/mission_session.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/alarm.dart';
import '../../core/models/location.dart';
import '../../core/models/notification_setting.dart';
import '../../core/models/skipped_occurrence.dart';
import '../../core/models/prayer_time.dart';
import '../../core/utils/prayer_utils.dart';
import '../services/upcoming_resolver.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/state_widgets.dart';
import '../../features/ramadan/domain/ramadan_countdown.dart';
import '../../l10n/l10n_extensions.dart';
import '../widgets/home/countdown_hero.dart';
import '../widgets/home/day_ruler.dart';
import '../widgets/home/home_top_bar.dart';
import '../widgets/home/prayer_grid.dart';
import '../widgets/home/upcoming_card.dart';

class HomeScreen extends StatefulWidget {
  /// Ramazan modu açık mı; sayaç ve başlıklar buna göre değişir.
  final bool ramadanActive;

  final Location location;
  final PrayerTime? todaysPrayerTime;
  final PrayerTime? tomorrowsPrayerTime;
  final DateTime? lastUpdateTime;
  final String dataSource;
  final VoidCallback? onSettingsTap;

  /// "Tümünü gör" — Hatırlatıcılar sekmesine geçer (push değil).
  final VoidCallback? onSeeReminders;

  final VoidCallback? onRefresh;
  final VoidCallback? onGpsRefresh;
  final VoidCallback? onLocationTap;

  /// "SIRADAKİ" kartının kaynağı: pencere içindeki tüm günler, açık bildirim
  /// ayarları ve kayıtlı alarmlar.
  final List<PrayerTime> prayerTimes;
  final List<NotificationSetting> notificationSettings;
  final List<Alarm> alarms;

  /// "Yalnızca bu sefer" atlanmış örnekler ve anahtar geri çağrısı.
  final Set<SkippedOccurrence> skips;

  /// Bekleyen görev oturumu; ertelenmiş alarm bilgisi için.
  final MissionSession? missionSession;
  final void Function(SkippedOccurrence occurrence, bool skipped)?
  onSkipChanged;

  final bool isLoading;

  /// Arka planda yenileme sürüyor. Ekrandaki vakitler yerinde kalır, üst
  /// çubukta ince bir gösterge çizilir.
  final bool isRefreshing;

  final String? errorMessage;

  const HomeScreen({
    this.missionSession,
    this.ramadanActive = false,
    super.key,
    required this.location,
    this.todaysPrayerTime,
    this.tomorrowsPrayerTime,
    this.lastUpdateTime,
    this.dataSource = 'Aladhan API',
    this.onSettingsTap,
    this.onSeeReminders,
    this.onRefresh,
    this.onGpsRefresh,
    this.onLocationTap,
    this.prayerTimes = const [],
    this.notificationSettings = const [],
    this.alarms = const [],
    this.skips = const {},
    this.onSkipChanged,
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
                onSettingsTap: widget.onSettingsTap ?? () {},
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
    final nextName = ramadan == null
        ? PrayerUtils.getNextPrayerName(today)
        : (ramadan.kind == RamadanCountdownKind.iftar
              ? context.l10n.ramadanIftarCountdown
              : context.l10n.ramadanSuhoorCountdown);

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
        UpcomingCard(
          missionSession: widget.missionSession,
          now: now,
          notification: resolveNextNotification(
            settings: widget.notificationSettings,
            prayerTimes: widget.prayerTimes,
            now: now,
          ),
          alarm: resolveNextAlarm(
            alarms: widget.alarms,
            prayerTimes: widget.prayerTimes,
            now: now,
          ),
          skips: widget.skips,
          onSkipChanged: widget.onSkipChanged,
          onSeeAll: widget.onSeeReminders ?? () {},
        ),
        // Artan boşluk altta toplanır; içerik yukarı yaslı kalır.
        const Spacer(),
      ],
    );
  }
}
