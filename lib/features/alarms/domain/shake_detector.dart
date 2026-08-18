import 'dart:math';

/// Sallama sayacı: ivmeölçer örneklerinden "sallama" olaylarını çıkarır.
///
/// Saf mantık; sensöre bağlı değil, örnekleri dışarıdan alır. Böylece
/// eşik ve bekleme davranışı cihaz olmadan test edilebiliyor.
class ShakeDetector {
  /// Yerçekimi çıkarıldıktan sonra sallama sayılacak ivme büyüklüğü (m/s²).
  ///
  /// Cebe koyup yürümek bu eşiği geçmemeli; bilinçli bir silkeleme geçmeli.
  static const double thresholdMps2 = 12;

  /// İki sallama arasında beklenen en kısa süre. Tek bir silkelemenin
  /// birden çok kez sayılmasını engeller.
  static const Duration cooldown = Duration(milliseconds: 350);

  /// Yerçekimi ivmesi; büyüklükten çıkarılır.
  static const double _gravity = 9.81;

  int _count = 0;
  DateTime? _lastShakeAt;

  int get count => _count;

  void reset() {
    _count = 0;
    _lastShakeAt = null;
  }

  /// Bir ivmeölçer örneği işler; bu örnek yeni bir sallama sayıldıysa true.
  bool onSample({
    required double x,
    required double y,
    required double z,
    required DateTime at,
  }) {
    final magnitude = sqrt(x * x + y * y + z * z) - _gravity;
    if (magnitude < thresholdMps2) return false;

    final last = _lastShakeAt;
    if (last != null && at.difference(last) < cooldown) return false;

    _lastShakeAt = at;
    _count++;
    return true;
  }

  /// [level] için hedeflenen sallama sayısı. Zorluk süreyle değil iş
  /// miktarıyla artar.
  static int targetFor(int level) => switch (level.clamp(1, 3)) {
    1 => 15,
    2 => 25,
    _ => 40,
  };
}
