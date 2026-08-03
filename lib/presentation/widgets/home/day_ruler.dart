import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/prayer_time.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// Gece uçlarının yatak rengine göre ne kadar sönük çizileceği.
const double _kNightDim = 0.45;

/// [now] anının **takvim gününün** (00:00–24:00) içindeki oranı (0..1).
///
/// Aralık İmsak→Yatsı değil gün başı→gün sonu: aksi halde Yatsı'dan gece
/// yarısına kadar gösterge sağ uca yapışıp donuyor, gece yarısı ile İmsak
/// arasında da sol uçta duruyordu. Yaz/kış farkını doğru taşımak için gün
/// uzunluğu takvimden hesaplanır (DST günleri 23 veya 25 saat olabilir).
double dayProgress(PrayerTime prayerTime, DateTime now) {
  final date = prayerTime.date;
  final start = DateTime(date.year, date.month, date.day);
  final end = DateTime(date.year, date.month, date.day + 1);

  final span = end.difference(start).inSeconds;
  if (span <= 0) return 0;

  final passed = now.difference(start).inSeconds;
  return (passed / span).clamp(0.0, 1.0);
}

/// Günün 00:00–24:00 şeridi: ilerleme, vakit çentikleri ve şu anki saat.
///
/// İmsak öncesi ve Yatsı sonrası uçlar daha sönük çizilir; böylece hiçbir
/// vakit içermeyen bu bölümler boşluk değil "gece" olarak okunur. Kışın bu
/// iki uç şeridin yarısına yaklaşır.
///
/// Uçlardaki İmsak/Yatsı saatleri yazılmaz: aynı iki değer hemen altındaki
/// vakit ızgarasında zaten var.
class DayRuler extends StatelessWidget {
  /// Şerit yüksekliği: üstte saat etiketi, ortada 5px yatak.
  static const double height = 26;

  final PrayerTime prayerTime;
  final DateTime now;

  const DayRuler({super.key, required this.prayerTime, required this.now});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final progress = dayProgress(prayerTime, now);
    final marks = <DateTime>[
      prayerTime.fajr,
      prayerTime.sunrise,
      prayerTime.dhuhr,
      prayerTime.asr,
      prayerTime.maghrib,
      prayerTime.isha,
    ];

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final markerX = width * progress;
          final dayStart = dayProgress(prayerTime, prayerTime.fajr);
          final dayEnd = dayProgress(prayerTime, prayerTime.isha);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Yatağın tamamı gece tonunda; üzerine İmsak→Yatsı penceresi
              // normal tonda bindirilir. İki uç böylece kendiliğinden sönük
              // kalır.
              Positioned(
                left: 0,
                right: 0,
                top: 16,
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: tokens.mutedTrack.withValues(
                      alpha: tokens.mutedTrack.a * _kNightDim,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Positioned(
                left: width * dayStart,
                top: 16,
                child: Container(
                  width: width * (dayEnd - dayStart),
                  height: 5,
                  color: tokens.mutedTrack,
                ),
              ),
              Positioned(
                left: 0,
                top: 16,
                child: Container(
                  width: markerX,
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        tokens.accent.withValues(alpha: 0.4),
                        tokens.accent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              for (final mark in marks)
                Positioned(
                  left: (width - 2) * dayProgress(prayerTime, mark),
                  top: 12,
                  child: Container(
                    key: const Key('ruler_tick'),
                    width: 2,
                    height: 13,
                    decoration: BoxDecoration(
                      // Gecmis vakitler vurgulu, gelecek olanlar sonuk.
                      color: mark.isAfter(now)
                          ? tokens.mutedTrack
                          : tokens.accent.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              Positioned(
                // Etiket gece yarısına yakın saatlerde şeridin dışına
                // taşmasın diye kenarlara sıkıştırılır.
                left: (markerX - 20).clamp(0.0, (width - 40).clamp(0.0, width)),
                top: 0,
                child: SizedBox(
                  width: 40,
                  child: Text(
                    DateFormat('HH:mm').format(now),
                    textAlign: TextAlign.center,
                    style: AppTypography.rulerTime.copyWith(
                      color: tokens.accent,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: markerX - 8,
                top: 10.5,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: tokens.accent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tokens.backgroundStops[1],
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.accent.withValues(alpha: 0.5),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
