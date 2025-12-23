import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/prayer_time.dart';
import '../../core/models/location.dart';
import '../../core/models/notification_setting.dart';

class HomeScreen extends StatelessWidget {
  final Location location;
  final PrayerTime? todaysPrayerTime;
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
    this.lastUpdateTime,
    this.dataSource = 'Diyanet (Awqat Salah API)',
    this.onCalendarTap,
    this.onSettingsTap,
    this.onNotificationSettingsTap,
    this.onRefresh,
    this.isLoading = false,
    this.errorMessage,
  });

  PrayerType? _getNextPrayer(PrayerTime prayerTime) {
    final now = DateTime.now();

    if (now.isBefore(prayerTime.fajr)) return PrayerType.fajr;
    if (now.isBefore(prayerTime.sunrise)) return PrayerType.sunrise;
    if (now.isBefore(prayerTime.dhuhr)) return PrayerType.dhuhr;
    if (now.isBefore(prayerTime.asr)) return PrayerType.asr;
    if (now.isBefore(prayerTime.maghrib)) return PrayerType.maghrib;
    if (now.isBefore(prayerTime.isha)) return PrayerType.isha;

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
              '${location.province} / ${location.district}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (onNotificationSettingsTap != null)
            IconButton(
              key: const Key('notification_settings_button'),
              icon: const Icon(Icons.notifications),
              onPressed: onNotificationSettingsTap,
            ),
          if (onSettingsTap != null)
            IconButton(
              key: const Key('settings_button'),
              icon: const Icon(Icons.settings),
              onPressed: onSettingsTap,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          onRefresh?.call();
        },
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
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
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    if (onRefresh != null)
                      ElevatedButton(
                        onPressed: onRefresh,
                        child: const Text('Yeniden Dene'),
                      ),
                  ],
                ),
              )
            : todaysPrayerTime == null
            ? const Center(child: Text('Veri bulunamadı'))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_getNextPrayer(todaysPrayerTime!) != null)
                        _buildNextPrayerCard(
                          todaysPrayerTime!,
                          _getNextPrayer(todaysPrayerTime!)!,
                        ),
                      const SizedBox(height: 16),
                      _buildPrayerTimesList(todaysPrayerTime!),
                      const SizedBox(height: 16),
                      _buildInfoSection(),
                      const SizedBox(height: 16),
                      if (onCalendarTap != null)
                        OutlinedButton.icon(
                          key: const Key('calendar_button'),
                          onPressed: onCalendarTap,
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

  Widget _buildNextPrayerCard(PrayerTime prayerTime, PrayerType nextPrayer) {
    final prayerDateTime = _getPrayerTime(prayerTime, nextPrayer);
    final timeFormat = DateFormat('HH:mm');

    return Card(
      key: const Key('next_prayer_card'),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Sonraki Vakit',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              _getPrayerName(nextPrayer),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              timeFormat.format(prayerDateTime),
              style: const TextStyle(
                fontSize: 32,
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

    final nextPrayer = _getNextPrayer(prayerTime);

    return Card(
      child: Column(
        children: prayers.map((prayer) {
          final prayerDateTime = _getPrayerTime(prayerTime, prayer);
          final timeFormat = DateFormat('HH:mm');
          final isNext = prayer == nextPrayer;

          return ListTile(
            key: Key('prayer_${prayer.name}'),
            leading: Icon(
              Icons.access_time,
              color: isNext ? Colors.blue : null,
            ),
            title: Text(
              _getPrayerName(prayer),
              style: TextStyle(
                fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                color: isNext ? Colors.blue : null,
              ),
            ),
            trailing: Text(
              timeFormat.format(prayerDateTime),
              style: TextStyle(
                fontSize: 18,
                fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                color: isNext ? Colors.blue : null,
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
                'Kaynak: $dataSource',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
        if (lastUpdateTime != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.update, size: 16),
              const SizedBox(width: 8),
              Text(
                'Son güncelleme: ${dateFormat.format(lastUpdateTime!)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
