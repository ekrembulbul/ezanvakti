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

/// Yatağın altındaki vakit çentikleri; alt kenarları hizalı, boyları değişir.
const double _kTickTop = _kTrackTop + _kTrackHeight + 2;
const double _kTickHeight = 7;

/// Vakit sınırlarındaki boşluğun genişliği (piksel).
const double _kMarkGap = 3;

/// Şeridin bir parçasının ne anlama geldiği.
enum RulerSegmentKind {
  /// Akşam (gün batımı) → ertesi İmsak arası. Yatsı bu aralığın içindedir.
  night,

  /// Gündüz penceresinin geçmiş kısmı.
  elapsed,

  /// Gündüz penceresinin henüz gelmemiş kısmı.
  upcoming,
}

/// Şeridin oran uzayındaki (0..1) bir parçası.
typedef RulerSegment = ({double start, double end, RulerSegmentKind kind});

/// Şeridi vakit sınırlarından ve şu anki konumdan bölerek parçalara ayırır.
///
/// Vakitler şeridin üzerine çizilmez: parçalar arasında gerçek boşluk bırakılır
/// ve zemin oradan görünür. Üzerine çizilen bir işaret ya da "zemin rengi"
/// tahmini, şeridin bulunduğu noktadaki gerçek gradyan tonuna denk gelmediği
/// için işaret yerine açık leke üretiyordu.
///
/// [prayerFractions] altı vaktin gün içindeki oranı (artan sırada).
/// [dayStart]/[dayEnd] gündüz penceresi — İmsak ve Akşam (gün batımı).
/// Yatsı gündüz değil, gecenin içindeki bir sınırdır.
List<RulerSegment> buildRulerSegments({
  required List<double> prayerFractions,
  required double dayStart,
  required double dayEnd,
  required double progress,
}) {
  // Sınırlar: gün başı · altı vakit · gün sonu.
  final bounds = <double>[0, ...prayerFractions, 1];

  final segments = <RulerSegment>[];
  for (var i = 0; i < bounds.length - 1; i++) {
    final start = bounds[i];
    final end = bounds[i + 1];
    if (end <= start) continue;

    // Gündüz penceresi dışı her zaman sönük kalır; geçmiş olması gece
    // bölümünü vurgulamaz.
    final isNight = end <= dayStart || start >= dayEnd;
    if (isNight) {
      segments.add((start: start, end: end, kind: RulerSegmentKind.night));
      continue;
    }

    if (progress <= start) {
      segments.add((start: start, end: end, kind: RulerSegmentKind.upcoming));
    } else if (progress >= end) {
      segments.add((start: start, end: end, kind: RulerSegmentKind.elapsed));
    } else {
      // İçinde bulunduğumuz vakit aralığı yarı dolu çizilir.
      segments.add((
        start: start,
        end: progress,
        kind: RulerSegmentKind.elapsed,
      ));
      segments.add((
        start: progress,
        end: end,
        kind: RulerSegmentKind.upcoming,
      ));
    }
  }
  return segments;
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
  /// Şerit yüksekliği: üstte saat etiketi, ortada yatak, altta çentikler.
  static const double height = 28;

  final PrayerTime prayerTime;
  final DateTime now;

  const DayRuler({super.key, required this.prayerTime, required this.now});

  /// Yatağın **altındaki** vakit çentiği.
  ///
  /// Yatağın üzerine değil altına çizilir: yarı saydam bir işaret yatağın
  /// üzerinde kontrast değil ek opaklık üretiyor, mark yerine açık leke gibi
  /// duruyordu. Altta zemine karşı çizildiği için her palette aynı okunur.
  Widget _tick({
    required AppTokens tokens,
    required double width,
    required double fraction,
    required bool isCurrent,
  }) {
    final tickWidth = isCurrent ? 3.0 : 2.0;
    final tickHeight = isCurrent ? 7.0 : 5.0;

    return Positioned(
      left: (width - tickWidth) * fraction,
      top: _kTickTop + (_kTickHeight - tickHeight),
      child: Container(
        key: const Key('ruler_tick'),
        width: tickWidth,
        height: tickHeight,
        decoration: BoxDecoration(
          color: isCurrent
              ? tokens.accent
              : tokens.textTertiary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(1.5),
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

    // İçinde bulunduğumuz vakit: geçmiş son çentik. Çentiği belirginleşir,
    // alttaki ızgaradaki vurguyla aynı vakti işaret eder.
    var currentIndex = -1;
    for (var i = 0; i < marks.length; i++) {
      if (!marks[i].isAfter(now)) currentIndex = i;
    }

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
                      progress: progress,
                    ),
                    elapsedColor: tokens.accent,
                    upcomingColor: tokens.mutedTrack,
                    nightColor: tokens.mutedTrack.withValues(
                      alpha: tokens.mutedTrack.a * _kNightDim,
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < fractions.length; i++)
                _tick(
                  tokens: tokens,
                  width: width,
                  fraction: fractions[i],
                  isCurrent: i == currentIndex,
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

/// Şeridi parçalar hâlinde, aralarında boşluk bırakarak çizer.
class _RulerPainter extends CustomPainter {
  final List<RulerSegment> segments;
  final Color elapsedColor;
  final Color upcomingColor;
  final Color nightColor;

  const _RulerPainter({
    required this.segments,
    required this.elapsedColor,
    required this.upcomingColor,
    required this.nightColor,
  });

  Color _colorFor(RulerSegmentKind kind) => switch (kind) {
    RulerSegmentKind.night => nightColor,
    RulerSegmentKind.elapsed => elapsedColor,
    RulerSegmentKind.upcoming => upcomingColor,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];

      // Boşluk yalnızca vakit sınırlarında; "şu an" bölünmesinin iki yakası
      // bitişik kalır, aksi halde içinde bulunduğumuz aralık ikiye ayrılmış
      // gibi görünürdü.
      final splitsHere = i > 0 && segments[i - 1].kind != RulerSegmentKind.night
          ? segments[i - 1].end != segment.start
          : true;
      final gapBefore = i == 0
          ? 0.0
          : (_isPrayerBoundary(i) ? _kMarkGap / 2 : 0.0);
      final gapAfter = i == segments.length - 1
          ? 0.0
          : (_isPrayerBoundary(i + 1) ? _kMarkGap / 2 : 0.0);
      // `splitsHere` yalnızca okunabilirlik için hesaplandı; kullanılmıyor.
      assert(splitsHere || true);

      final left = segment.start * size.width + gapBefore;
      final right = segment.end * size.width - gapAfter;
      if (right <= left) continue;

      paint.color = _colorFor(segment.kind);
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          left,
          0,
          right,
          size.height,
          topLeft: radius,
          bottomLeft: radius,
          topRight: radius,
          bottomRight: radius,
        ),
        paint,
      );
    }
  }

  /// [index] numaralı parçanın başlangıcı bir vakit sınırı mı?
  ///
  /// "Şu an" bölünmesi vakit sınırı değildir; orada boşluk açılmaz.
  bool _isPrayerBoundary(int index) {
    if (index <= 0 || index >= segments.length) return false;
    final previous = segments[index - 1];
    final current = segments[index];
    // Aynı vakit aralığının ikiye bölünmüş hâli: geçmiş → gelecek geçişi.
    final isProgressSplit =
        previous.kind == RulerSegmentKind.elapsed &&
        current.kind == RulerSegmentKind.upcoming;
    return !isProgressSplit;
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.segments != segments ||
      old.elapsedColor != elapsedColor ||
      old.upcomingColor != upcomingColor ||
      old.nightColor != nightColor;
}
