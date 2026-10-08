import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/prayer_time.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../features/prayer_times/domain/day_ruler_math.dart';
import '../../../features/prayer_times/domain/kerahat_times.dart';

export '../../../features/prayer_times/domain/day_ruler_math.dart';

// ── Yatak ve çentik tonları ────────────────────────────────────────────────
// Üç rol, üç ağırlık. Gündüz vurgu rengini taşır; gece ve çentikler nötr
// Metin3 rampasında kalır ki gündüz penceresi tek başına öne çıksın.

/// Gece uçları.
const double _kNightOpacity = 0.4;

/// Vakit çentikleri.
const double _kTickOpacity = 0.7;

/// Saat etiketinin kutusu. `height: 1.0` ile satır kutusu font boyuna eşitlenir
/// (varsayılan ~1.36 çarpanı kutuyu 15px'e çıkarıp noktanın üstüne bindiriyordu).
const double _kLabelHeight = 12;

/// Etiket ile noktanın üst kenarı arasındaki boşluk.
const double _kLabelGap = 3;

/// Şu anki konumu gösteren nokta.
const double _kDotSize = 16;

/// Nokta yataktan kalın; dikey merkez ona göre belirlenir.
const double _kTrackCenter = _kLabelHeight + _kLabelGap + _kDotSize / 2;
const double _kTrackHeight = 5;
const double _kTrackTop = _kTrackCenter - _kTrackHeight / 2;

/// Yatağın altındaki vakit çentikleri.
const double _kTickTop = _kTrackTop + _kTrackHeight + 2;
const double _kTickWidth = 2;
const double _kTickHeight = 7;

/// Vakit sınırlarındaki boşluğun genişliği (piksel).
const double _kMarkGap = 3;

/// Bir parçanın vakit sınırı boşlukları çıktıktan sonra kalan çizim genişliği.
double paintedRulerSegmentWidth(RulerSegment segment, double rulerWidth) {
  final gapBefore = segment.gapBefore ? _kMarkGap / 2 : 0.0;
  final gapAfter = segment.gapAfter ? _kMarkGap / 2 : 0.0;
  return ((segment.end - segment.start) * rulerWidth - gapBefore - gapAfter)
      .clamp(0.0, rulerWidth);
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
  /// Şerit yüksekliği: üstte saat etiketi, ortada yatak, altta çentikler.
  static const double height = _kTickTop + _kTickHeight;

  final PrayerTime prayerTime;
  final DateTime now;
  final List<KerahatInterval> kerahatIntervals;

  const DayRuler({
    super.key,
    required this.prayerTime,
    required this.now,
    this.kerahatIntervals = const [],
  });

  /// Yatağın **altındaki** vakit çentiği.
  ///
  /// Yatağın üzerine değil altına çizilir: yarı saydam bir işaret yatağın
  /// üzerinde kontrast değil ek opaklık üretiyor, mark yerine açık leke gibi
  /// duruyordu. Altta zemine karşı çizildiği için her palette aynı okunur.
  ///
  /// Altı çentik de aynı: hangi vaktin içinde olduğumuzu şeridin kendi
  /// renk geçişi ve alttaki ızgara zaten söylüyor.
  Widget _tick({
    required AppTokens tokens,
    required double width,
    required double fraction,
  }) {
    return Positioned(
      left: (width - _kTickWidth) * fraction,
      top: _kTickTop,
      child: Container(
        key: const Key('ruler_tick'),
        width: _kTickWidth,
        height: _kTickHeight,
        decoration: BoxDecoration(
          // Hafif soluk: cizgiler seridin okunusunu bolmemeli.
          color: tokens.textTertiary.withValues(alpha: _kTickOpacity),
          borderRadius: BorderRadius.circular(1),
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
    final fractions = [for (final mark in marks) dayProgress(prayerTime, mark)];
    final kerahatRanges = [
      for (final interval in kerahatIntervals)
        (
          start: dayProgress(prayerTime, interval.start),
          end: dayProgress(prayerTime, interval.end),
        ),
    ];

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final markerX = width * progress;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Parçalar arasında **gerçek boşluk** bırakılır; zemin oradan
              // görünür. Üzerine çizilen bir işaret ya da "zemin rengi"
              // tahmini, şeridin bulunduğu noktadaki gradyan tonuna denk
              // gelmediği için işaret yerine açık leke üretiyordu.
              Positioned(
                left: 0,
                right: 0,
                top: _kTrackTop,
                child: CustomPaint(
                  size: Size(width, _kTrackHeight),
                  painter: _RulerPainter(
                    segments: buildRulerSegments(
                      prayerFractions: fractions,
                      // Gündüz = İmsak → Akşam (gün batımı). Yatsı gündüzün
                      // sonu değil, gecenin içindeki bir sınır.
                      dayStart: fractions[0],
                      dayEnd: fractions[4],
                      kerahatRanges: kerahatRanges,
                    ),
                    dayColor: tokens.accent,
                    nightColor: tokens.textTertiary.withValues(
                      alpha: _kNightOpacity,
                    ),
                    kerahatColor: tokens.kerahatLine,
                  ),
                ),
              ),
              for (final fraction in fractions)
                _tick(tokens: tokens, width: width, fraction: fraction),
              Positioned(
                // Etiket gece yarısına yakın saatlerde şeridin dışına
                // taşmasın diye kenarlara sıkıştırılır.
                left: (markerX - 20).clamp(0.0, (width - 40).clamp(0.0, width)),
                top: 0,
                child: SizedBox(
                  width: 40,
                  height: _kLabelHeight,
                  child: Text(
                    DateFormat('HH:mm').format(now),
                    textAlign: TextAlign.center,
                    style: AppTypography.rulerTime.copyWith(
                      color: tokens.accent,
                      height: 1,
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

/// Şeridi parçalar hâlinde, aralarında boşluk bırakarak çizer.
class _RulerPainter extends CustomPainter {
  final List<RulerSegment> segments;
  final Color dayColor;
  final Color nightColor;
  final Color kerahatColor;

  const _RulerPainter({
    required this.segments,
    required this.dayColor,
    required this.nightColor,
    required this.kerahatColor,
  });

  Color _colorFor(RulerSegmentKind kind) => switch (kind) {
    RulerSegmentKind.day => dayColor,
    RulerSegmentKind.night => nightColor,
    RulerSegmentKind.kerahat => kerahatColor,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];

      // Kerahat başlangıç/bitişlerinde boşluk yoktur. Yalnızca altı gerçek
      // vakit sınırı yatağı böler; böylece 10 dakikalık öğle parçası kaybolmaz.
      final gapBefore = segment.gapBefore ? _kMarkGap / 2 : 0.0;

      final left = segment.start * size.width + gapBefore;
      final right = left + paintedRulerSegmentWidth(segment, size.width);
      if (right <= left) continue;

      final leftRadius = segment.start == 0 || segment.gapBefore
          ? radius
          : Radius.zero;
      final rightRadius = segment.end == 1 || segment.gapAfter
          ? radius
          : Radius.zero;
      paint.color = _colorFor(segment.kind);
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          left,
          0,
          right,
          size.height,
          topLeft: leftRadius,
          bottomLeft: leftRadius,
          topRight: rightRadius,
          bottomRight: rightRadius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.segments != segments ||
      old.dayColor != dayColor ||
      old.nightColor != nightColor ||
      old.kerahatColor != kerahatColor;
}
