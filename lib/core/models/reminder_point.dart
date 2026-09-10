import 'derived_time.dart';
import 'notification_setting.dart' show PrayerType;

/// Bir bildirimin hedefi: ya bir namaz vakti ya da altı vakitten hesaplanan
/// bir nokta (kerahat, gece yarısı, teheccüd…).
///
/// Depoda hedef `(prayerType, derivedKind)` çiftiyle tutulur ve hesaplanan
/// noktada `prayerType` o noktanın **çıpasıdır** (bkz. [DerivedTimeKindX.anchor]).
/// Bu bağ ekranda kullanıcıya görünmemeli — eski alt sayfada çip seçilince
/// üstteki vaktin kendiliğinden değişmesi "ne oldu?" dedirtiyordu. Sınıf,
/// seçiciye tek bir değer verir; çıpa dönüşümünü içeride yapar.
class ReminderPoint {
  final PrayerType anchor;
  final DerivedTimeKind? derived;

  const ReminderPoint.prayer(this.anchor) : derived = null;

  ReminderPoint.derivedPoint(DerivedTimeKind kind)
    : anchor = kind.anchor,
      derived = kind;

  /// Depodaki `(prayerType, derivedKind)` çiftinden nokta.
  factory ReminderPoint.of(PrayerType type, DerivedTimeKind? kind) =>
      kind == null
      ? ReminderPoint.prayer(type)
      : ReminderPoint.derivedPoint(kind);

  bool get isDerived => derived != null;

  /// Seçicideki sıra: altı vakit, sonra beş hesaplanan nokta.
  static List<ReminderPoint> get all => [
    for (final type in PrayerType.values) ReminderPoint.prayer(type),
    for (final kind in DerivedTimeKind.values) ReminderPoint.derivedPoint(kind),
  ];

  @override
  bool operator ==(Object other) =>
      other is ReminderPoint &&
      other.anchor == anchor &&
      other.derived == derived;

  @override
  int get hashCode => Object.hash(anchor, derived);

  @override
  String toString() => 'ReminderPoint($anchor, $derived)';
}
