import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/prayer_time.dart';
import '../../core/models/location.dart';
import '../../core/models/notification_setting.dart';

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
    this.isLoading = false,
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
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  PrayerType? _getCurrentPrayer(PrayerTime prayerTime) {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    if (now.isBefore(prayerTime.fajr) ||
        now.isBefore(midnight.add(const Duration(hours: 0)))) {
      return null;
    }
    if (now.isBefore(prayerTime.sunrise)) return PrayerType.fajr;
    if (now.isBefore(prayerTime.dhuhr)) return PrayerType.sunrise;
    if (now.isBefore(prayerTime.asr)) return PrayerType.dhuhr;
    if (now.isBefore(prayerTime.maghrib)) return PrayerType.asr;
    if (now.isBefore(prayerTime.isha)) return PrayerType.maghrib;

    final todayMidnight = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    if (now.isBefore(todayMidnight)) {
      return PrayerType.isha;
    }

    return null;
  }

  DateTime? _getNextPrayerTime() {
    if (widget.todaysPrayerTime == null) return null;

    final now = DateTime.now();
    final prayerTime = widget.todaysPrayerTime!;

    if (now.isBefore(prayerTime.fajr)) return prayerTime.fajr;
    if (now.isBefore(prayerTime.sunrise)) return prayerTime.sunrise;
    if (now.isBefore(prayerTime.dhuhr)) return prayerTime.dhuhr;
    if (now.isBefore(prayerTime.asr)) return prayerTime.asr;
    if (now.isBefore(prayerTime.maghrib)) return prayerTime.maghrib;
    if (now.isBefore(prayerTime.isha)) return prayerTime.isha;

    if (widget.tomorrowsPrayerTime != null) {
      return widget.tomorrowsPrayerTime!.fajr;
    }

    return null;
  }

  String? _getNextPrayerName() {
    if (widget.todaysPrayerTime == null) return null;

    final now = DateTime.now();
    final prayerTime = widget.todaysPrayerTime!;

    if (now.isBefore(prayerTime.fajr)) return 'İmsak';
    if (now.isBefore(prayerTime.sunrise)) return 'Güneş';
    if (now.isBefore(prayerTime.dhuhr)) return 'Öğle';
    if (now.isBefore(prayerTime.asr)) return 'İkindi';
    if (now.isBefore(prayerTime.maghrib)) return 'Akşam';
    if (now.isBefore(prayerTime.isha)) return 'Yatsı';

    if (widget.tomorrowsPrayerTime != null) {
      return 'İmsak';
    }

    return null;
  }

  String _getPrayerName(PrayerType type) {
    switch (type) {
      case PrayerType.fajr:
        return 'İmsak';
      case PrayerType.sunrise:
        return 'Güneş';
      case PrayerType.dhuhr:
        return 'Öğle';
      case PrayerType.asr:
        return 'İkindi';
      case PrayerType.maghrib:
        return 'Akşam';
      case PrayerType.isha:
        return 'Yatsı';
    }
  }

  DateTime _getPrayerTime(PrayerTime prayerTime, PrayerType type) {
    switch (type) {
      case PrayerType.fajr:
        return prayerTime.fajr;
      case PrayerType.sunrise:
        return prayerTime.sunrise;
      case PrayerType.dhuhr:
        return prayerTime.dhuhr;
      case PrayerType.asr:
        return prayerTime.asr;
      case PrayerType.maghrib:
        return prayerTime.maghrib;
      case PrayerType.isha:
        return prayerTime.isha;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ezan Vakti'),
            Text(
              '${widget.location.province} / ${widget.location.district}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (widget.onNotificationSettingsTap != null)
            IconButton(
              key: const Key('notification_settings_button'),
              icon: const Icon(Icons.notifications),
              onPressed: widget.onNotificationSettingsTap,
            ),
          if (widget.onSettingsTap != null)
            IconButton(
              key: const Key('settings_button'),
              icon: const Icon(Icons.settings),
              onPressed: widget.onSettingsTap,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          widget.onRefresh?.call();
        },
        child: widget.isLoading
            ? const Center(child: CircularProgressIndicator())
            : widget.errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    if (widget.onRefresh != null)
                      ElevatedButton(
                        onPressed: widget.onRefresh,
                        child: const Text('Yeniden Dene'),
                      ),
                  ],
                ),
              )
            : widget.todaysPrayerTime == null
            ? const Center(child: Text('Veri bulunamadı'))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCountdownCard(),
                      const SizedBox(height: 16),
                      _buildPrayerTimesList(widget.todaysPrayerTime!),
                      const SizedBox(height: 16),
                      _buildInfoSection(),
                      const SizedBox(height: 16),
                      if (widget.onCalendarTap != null)
                        OutlinedButton.icon(
                          key: const Key('calendar_button'),
                          onPressed: widget.onCalendarTap,
                          icon: const Icon(Icons.calendar_month),
                          label: const Text('Vakit Takvimi'),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildCountdownCard() {
    final nextPrayerTime = _getNextPrayerTime();
    final nextPrayerName = _getNextPrayerName();

    if (nextPrayerTime == null || nextPrayerName == null) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final difference = nextPrayerTime.difference(now);

    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    final seconds = difference.inSeconds.remainder(60);

    String countdownText;
    if (hours > 0) {
      countdownText =
          '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      countdownText =
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return Card(
      key: const Key('countdown_card'),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Sonraki Vakte Kalan Süre',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              nextPrayerName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              countdownText,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerTimesList(PrayerTime prayerTime) {
    final prayers = [
      PrayerType.fajr,
      PrayerType.sunrise,
      PrayerType.dhuhr,
      PrayerType.asr,
      PrayerType.maghrib,
      PrayerType.isha,
    ];

    final currentPrayer = _getCurrentPrayer(prayerTime);

    return Card(
      child: Column(
        children: prayers.map((prayer) {
          final prayerDateTime = _getPrayerTime(prayerTime, prayer);
          final timeFormat = DateFormat('HH:mm');
          final isCurrent = prayer == currentPrayer;

          return ListTile(
            key: Key('prayer_${prayer.name}'),
            tileColor: isCurrent ? Colors.blue.shade50 : null,
            leading: Icon(
              Icons.access_time,
              color: isCurrent ? Colors.blue : null,
            ),
            title: Text(
              _getPrayerName(prayer),
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent ? Colors.blue : null,
              ),
            ),
            trailing: Text(
              timeFormat.format(prayerDateTime),
              style: TextStyle(
                fontSize: 18,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent ? Colors.blue : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInfoSection() {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.info_outline, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Kaynak: ${widget.dataSource}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
        if (widget.lastUpdateTime != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.update, size: 16),
              const SizedBox(width: 8),
              Text(
                'Son Güncelleme: ${dateFormat.format(widget.lastUpdateTime!)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
