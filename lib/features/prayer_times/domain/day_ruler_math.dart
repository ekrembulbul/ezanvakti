import '../../../core/models/prayer_time.dart';

/// Gün cetvelinin saf hesapları: ana ekran cetveli ve widget'lar (snapshot'taki
/// `ruler`) aynı parçalamayı kullanır. Sunum katmanından taşındı; çizim
/// `day_ruler.dart`'ta kaldı.

/// Şeridin bir parçasının ne anlama geldiği.
///
/// Geçmiş/gelmemiş ayrımı yok: nerede olduğumuzu gösterge noktası söylüyor,
/// şeridin işi günün gündüz/gece yapısını göstermek.
enum RulerSegmentKind {
  /// İmsak → Akşam (gün batımı).
  day,

  /// Akşam → ertesi İmsak. Yatsı bu aralığın içindedir.
  night,

  /// Yaklaşık kerahat aralığı.
  kerahat,
}

typedef RulerRange = ({double start, double end});

/// Şeridin oran uzayındaki (0..1) bir parçası.
typedef RulerSegment = ({
  double start,
  double end,
  RulerSegmentKind kind,
  bool gapBefore,
  bool gapAfter,
});

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
  List<RulerRange> kerahatRanges = const [],
}) {
  final validPrayerFractions = prayerFractions
      .where((fraction) => fraction.isFinite && fraction >= 0 && fraction <= 1)
      .toSet();
  final validKerahatRanges = kerahatRanges
      .where(
        (range) =>
            range.start.isFinite &&
            range.end.isFinite &&
            range.start >= 0 &&
            range.end <= 1 &&
            range.end > range.start,
      )
      .toList();
  final bounds = <double>{
    0,
    ...validPrayerFractions,
    for (final range in validKerahatRanges) range.start,
    for (final range in validKerahatRanges) range.end,
    1,
  }.toList()..sort();

  final segments = <RulerSegment>[];
  for (var i = 0; i < bounds.length - 1; i++) {
    final start = bounds[i];
    final end = bounds[i + 1];
    if (end <= start) continue;

    final midpoint = start + (end - start) / 2;
    final isKerahat = validKerahatRanges.any(
      (range) => midpoint >= range.start && midpoint < range.end,
    );
    final isNight = end <= dayStart || start >= dayEnd;
    segments.add((
      start: start,
      end: end,
      kind: isKerahat
          ? RulerSegmentKind.kerahat
          : isNight
          ? RulerSegmentKind.night
          : RulerSegmentKind.day,
      gapBefore: validPrayerFractions.contains(start),
      gapAfter: validPrayerFractions.contains(end),
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
