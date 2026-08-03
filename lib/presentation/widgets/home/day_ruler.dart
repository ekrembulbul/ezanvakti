import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/prayer_time.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// Gece uçlarının yatak rengine göre ne kadar sönük çizileceği.
const double _kNightDim = 0.45;

/// Yatağın tek bir parçası: gece ucu ya da gündüz penceresi.
typedef _TrackSegment = ({double width, Color color});

/// Yatağı üst üste binmeyen üç parçaya böler: gece · gündüz · gece.
///
/// Genişliği sıfır olan parçalar atılır — kutup bölgelerinde Yatsı gece
/// yarısını aşabilir ve bir uç tamamen kapanabilir.
List<_TrackSegment> _trackSegments({
  required double width,
  required double dayStart,
  required double dayEnd,
  required Color dayColor,
  required Color nightColor,
}) {
  final segments = <_TrackSegment>[
    (width: width * dayStart, color: nightColor),
    (width: width * (dayEnd - dayStart).clamp(0.0, 1.0), color: dayColor),
    (width: width * (1 - dayEnd), color: nightColor),
  ];
  return segments.where((s) => s.width > 0).toList();
}

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
              // Gece ve gündüz bölümleri **yan yana** çizilir, üst üste değil:
              // token'lar yarı saydam olduğu için bindirme yapılınca gündüz
              // bölgesi iki kat alıyor ve amaçlanan oran (%45) tutmuyordu.
              Positioned(
                left: 0,
                right: 0,
                top: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 5,
                    child: Row(
                      children: [
                        for (final segment in _trackSegments(
                          width: width,
                          dayStart: dayStart,
                          dayEnd: dayEnd,
                          dayColor: tokens.mutedTrack,
                          nightColor: tokens.mutedTrack.withValues(
                            alpha: tokens.mutedTrack.a * _kNightDim,
                          ),
                        ))
                          SizedBox(
                            width: segment.width,
                            child: ColoredBox(color: segment.color),
                          ),
                      ],
                    ),
                  ),
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
