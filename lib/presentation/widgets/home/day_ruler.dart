import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/prayer_time.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

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

/// Şeridin bir parçasının ne anlama geldiği.
///
/// Geçmiş/gelmemiş ayrımı yok: nerede olduğumuzu gösterge noktası söylüyor,
/// şeridin işi günün gündüz/gece yapısını göstermek.
enum RulerSegmentKind {
  /// İmsak → Akşam (gün batımı).
  day,

  /// Akşam → ertesi İmsak. Yatsı bu aralığın içindedir.
  night,
}

/// Şeridin oran uzayındaki (0..1) bir parçası.
typedef RulerSegment = ({double start, double end, RulerSegmentKind kind});

/// Şeridi vakit sınırlarından bölerek parçalara ayırır.
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
}) {
  // Sınırlar: gün başı · altı vakit · gün sonu.
  final bounds = <double>[0, ...prayerFractions, 1];

  final segments = <RulerSegment>[];
  for (var i = 0; i < bounds.length - 1; i++) {
    final start = bounds[i];
    final end = bounds[i + 1];
    if (end <= start) continue;

    final isNight = end <= dayStart || start >= dayEnd;
    segments.add((
      start: start,
      end: end,
      kind: isNight ? RulerSegmentKind.night : RulerSegmentKind.day,
    ));
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
  static const double height = _kTickTop + _kTickHeight;

  final PrayerTime prayerTime;
  final DateTime now;

  const DayRuler({super.key, required this.prayerTime, required this.now});

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
                    ),
                    dayColor: tokens.accent,
                    nightColor: tokens.textTertiary.withValues(
                      alpha: _kNightOpacity,
                    ),
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

  const _RulerPainter({
    required this.segments,
    required this.dayColor,
    required this.nightColor,
  });

  Color _colorFor(RulerSegmentKind kind) => switch (kind) {
    RulerSegmentKind.day => dayColor,
    RulerSegmentKind.night => nightColor,
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
  bool _isPrayerBoundary(int index) => index > 0 && index < segments.length;

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.segments != segments ||
      old.dayColor != dayColor ||
      old.nightColor != nightColor;
}
