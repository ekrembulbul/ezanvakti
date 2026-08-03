import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/prayer_time.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// Gece uçlarının yatak rengine göre ne kadar sönük çizileceği.
const double _kNightDim = 0.45;

/// Yatağın kalınlığı ve dikey merkezi.
const double _kTrackTop = 16;
const double _kTrackHeight = 5;
const double _kTrackCenter = _kTrackTop + _kTrackHeight / 2;

/// Şu anki konumu gösteren nokta.
const double _kDotSize = 16;

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

  /// Tek bir vakit işareti.
  ///
  /// Vakitler şeridin üzerine **çizilmez**, şeridi zemin renginde keser.
  /// Üzerine çizilen bir işaret, altındaki yatak tonuna göre bazen daha açık
  /// bazen daha koyu kalıyordu; kesik her zeminde aynı okunur ve şerit doğal
  /// olarak altı vakit aralığına bölünmüş görünür.
  ///
  /// Sıradaki vakit istisna: kesik yerine tam accent, daha uzun bir işaret.
  /// Etiket yazmak mümkün değil (yaz/kış Akşam–Yatsı arası ~24pt, 3 harflik
  /// etiket ~26pt), bu yüzden "hangi çentik" sorusu ada değil sıraya bağlı.
  /// Adı sayacın etiketinde ve alttaki ızgarada zaten yazıyor.
  Widget _mark({
    required AppTokens tokens,
    required double width,
    required double progress,
    required bool isNext,
  }) {
    final markWidth = isNext ? 3.0 : 2.0;
    final markHeight = isNext ? 15.0 : _kTrackHeight;

    return Positioned(
      left: (width - markWidth) * progress,
      // İşaretler yatağın ortasında hizalı kalır.
      top: _kTrackCenter - markHeight / 2,
      child: Container(
        key: const Key('ruler_tick'),
        width: markWidth,
        height: markHeight,
        decoration: BoxDecoration(
          color: isNext ? tokens.accent : tokens.backgroundStops[1],
          borderRadius: BorderRadius.circular(isNext ? 1.5 : 0),
        ),
      ),
    );
  }

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

    // Sıradaki vakit: bugünkü ilk gelecek çentik. Yatsı'dan sonra hiçbiri
    // kalmaz — sıradaki İmsak ertesi güne ait ve bu şeritte yok.
    DateTime? nextMark;
    for (final mark in marks) {
      if (mark.isAfter(now)) {
        nextMark = mark;
        break;
      }
    }

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
                top: _kTrackTop,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: _kTrackHeight,
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
              for (final mark in marks)
                _mark(
                  tokens: tokens,
                  width: width,
                  progress: dayProgress(prayerTime, mark),
                  isNext: mark == nextMark,
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
                left: markerX - _kDotSize / 2,
                top: _kTrackCenter - _kDotSize / 2,
                child: Container(
                  width: _kDotSize,
                  height: _kDotSize,
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
