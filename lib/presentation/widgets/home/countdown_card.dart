import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/prayer_utils.dart';

class CountdownCard extends StatefulWidget {
  final DateTime nextPrayerTime;
  final String nextPrayerName;

  const CountdownCard({
    super.key,
    required this.nextPrayerTime,
    required this.nextPrayerName,
  });

  @override
  State<CountdownCard> createState() => _CountdownCardState();
}

class _CountdownCardState extends State<CountdownCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Self-contained per-second tick so only this card rebuilds, not the
    // whole home screen.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
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
    final rawDifference = widget.nextPrayerTime.difference(now);
    // Clamp to zero: when the prayer time passes, the parent recomputes the
    // next prayer shortly after; never show negative values in between.
    final difference = rawDifference.isNegative ? Duration.zero : rawDifference;
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    final seconds = difference.inSeconds.remainder(60);
    final nextPrayerName = widget.nextPrayerName;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.gold.withValues(alpha: 0.2),
            AppTheme.gold.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gold.withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PrayerUtils.getPrayerIconByName(nextPrayerName),
                color: AppTheme.gold,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                '$nextPrayerName Vaktine',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Sayaç rakamları kalan yüksekliğe göre ölçeklenir (kart büyüyünce
          // rakamlar büyür, küçülünce küçülür).
          Expanded(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TimeUnit(
                    value: hours.toString().padLeft(2, '0'),
                    label: 'Saat',
                  ),
                  const _TimeSeparator(),
                  _TimeUnit(
                    value: minutes.toString().padLeft(2, '0'),
                    label: 'Dakika',
                  ),
                  const _TimeSeparator(),
                  _TimeUnit(
                    value: seconds.toString().padLeft(2, '0'),
                    label: 'Saniye',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('HH:mm').format(widget.nextPrayerTime),
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeUnit extends StatelessWidget {
  final String value;
  final String label;

  const _TimeUnit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppTheme.gold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _TimeSeparator extends StatelessWidget {
  const _TimeSeparator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(
            ':',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.gold.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
