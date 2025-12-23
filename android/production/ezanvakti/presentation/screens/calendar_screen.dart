import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/prayer_time.dart';
import '../../core/models/location.dart';
import '../../core/models/notification_setting.dart';

class CalendarScreen extends StatelessWidget {
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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vakit Takvimi'),
            Text(
              '${location.province} / ${location.district}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
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
          : prayerTimes.isEmpty
          ? const Center(child: Text('Veri bulunamadı'))
          : RefreshIndicator(
              onRefresh: () async {
                onRefresh?.call();
              },
              child: ListView.builder(
                itemCount: prayerTimes.length,
                itemBuilder: (context, index) {
                  final prayerTime = prayerTimes[index];
                  return _buildDayCard(prayerTime);
                },
              ),
            ),
    );
  }

  Widget _buildDayCard(PrayerTime prayerTime) {
    final dateFormat = DateFormat('dd MMMM yyyy EEEE', 'tr_TR');
    final timeFormat = DateFormat('HH:mm');
    final isToday = _isToday(prayerTime.date);

    return Card(
      key: Key('day_card_${prayerTime.date.toIso8601String()}'),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isToday ? Colors.blue.shade50 : null,
      child: ExpansionTile(
        initiallyExpanded: isToday,
        title: Row(
          children: [
            if (isToday)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'BUGÜN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (isToday) const SizedBox(width: 8),
            Expanded(
              child: Text(
                dateFormat.format(prayerTime.date),
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1),
              },
              children: [
                _buildPrayerRow(PrayerType.fajr, prayerTime, timeFormat),
                _buildPrayerRow(PrayerType.sunrise, prayerTime, timeFormat),
                _buildPrayerRow(PrayerType.dhuhr, prayerTime, timeFormat),
                _buildPrayerRow(PrayerType.asr, prayerTime, timeFormat),
                _buildPrayerRow(PrayerType.maghrib, prayerTime, timeFormat),
                _buildPrayerRow(PrayerType.isha, prayerTime, timeFormat),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildPrayerRow(
    PrayerType type,
    PrayerTime prayerTime,
    DateFormat timeFormat,
  ) {
    final prayerDateTime = _getPrayerTime(prayerTime, type);

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            _getPrayerName(type),
            style: const TextStyle(fontSize: 16),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            timeFormat.format(prayerDateTime),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
