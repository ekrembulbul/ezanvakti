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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isToday ? Colors.blue.shade50 : Colors.grey.shade50,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        childrenPadding: const EdgeInsets.fromLTRB(32, 0, 32, 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide.none,
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide.none,
        ),
        initiallyExpanded: isToday,
        title: Row(
          children: [
            if (isToday)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade200,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
            if (isToday) const SizedBox(width: 10),
            Expanded(
              child: Text(
                dateFormat.format(prayerTime.date),
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 15,
                  color: Colors.blueGrey.shade900,
                ),
              ),
            ),
          ],
        ),
        children: [
          Column(
            children: [
              _buildPrayerRow(PrayerType.fajr, prayerTime, timeFormat),
              _buildDivider(),
              _buildPrayerRow(PrayerType.sunrise, prayerTime, timeFormat),
              _buildDivider(),
              _buildPrayerRow(PrayerType.dhuhr, prayerTime, timeFormat),
              _buildDivider(),
              _buildPrayerRow(PrayerType.asr, prayerTime, timeFormat),
              _buildDivider(),
              _buildPrayerRow(PrayerType.maghrib, prayerTime, timeFormat),
              _buildDivider(),
              _buildPrayerRow(PrayerType.isha, prayerTime, timeFormat),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerRow(
    PrayerType type,
    PrayerTime prayerTime,
    DateFormat timeFormat,
  ) {
    final prayerDateTime = _getPrayerTime(prayerTime, type);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _getPrayerName(type),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            timeFormat.format(prayerDateTime),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: Colors.blueGrey.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Divider(color: Colors.blueGrey.shade100, height: 2, thickness: 1),
    );
  }
}
