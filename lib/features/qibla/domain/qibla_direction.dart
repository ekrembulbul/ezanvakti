import 'dart:math' as math;

/// Kâbe yönünü hesaplar.
///
/// Saf: konum dışında hiçbir girdi almaz, cihaz sensörüne bakmaz. Pusula
/// ekranı bu açıyı cihazın yönüyle karşılaştırır.
class QiblaDirection {
  const QiblaDirection._();

  /// Kâbe'nin koordinatları (Mescid-i Haram).
  static const double kaabaLatitude = 21.4225;
  static const double kaabaLongitude = 39.8262;

  /// Verilen konumdan Kâbe'ye **büyük daire** yönü: kuzeyden saat yönünde
  /// 0–360°.
  ///
  /// Düz harita üzerinden çizilen doğru yanıltıcıdır (özellikle yüksek
  /// enlemlerde); kıble hesabı küre üzerindeki en kısa yolun başlangıç
  /// açısıdır.
  static double bearing({
    required double latitude,
    required double longitude,
  }) {
    final lat1 = _toRadians(latitude);
    final lat2 = _toRadians(kaabaLatitude);
    final deltaLon = _toRadians(kaabaLongitude - longitude);

    final y = math.sin(deltaLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLon);

    final degrees = _toDegrees(math.atan2(y, x));
    return (degrees + 360) % 360;
  }

  /// [heading] yönünden [qibla] yönüne en kısa dönüş: −180…180.
  ///
  /// İşaret dönüş yönünü verir: pozitif sağa, negatif sola. Arayüz oku bu
  /// değerle döndürür.
  static double difference(double heading, double qibla) {
    final raw = (qibla - heading + 540) % 360 - 180;
    // Tam ters yön matematikte hem -180 hem +180; aralığın üst ucunu seçiyoruz
    // ki dönüş yönü tutarlı olsun (ok her zaman aynı tarafa dönsün).
    return raw == -180 ? 180 : raw;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  static double _toDegrees(double radians) => radians * 180 / math.pi;
}
