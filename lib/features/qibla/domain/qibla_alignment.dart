/// Kıbleye "dönük" sayılma kararı.
///
/// Giriş eşiği dar tutulur ki onay gerçekten yöne bakınca gelsin; çıkış eşiği
/// biraz daha geniştir (histerezis): sensör 1°'lik adımlarla titrerken onay
/// yanıp sönmesin. Saf fonksiyon; sensöre ve arayüze bakmaz.
class QiblaAlignment {
  const QiblaAlignment._();

  /// Bu sapmanın altına inince hizalı sayılır.
  static const double enterDegrees = 2.5;

  /// Hizalıyken bu sapmayı aşınca hizadan çıkılır.
  static const double exitDegrees = 4;

  /// [delta] kıbleye olan işaretli fark (−180…180), [wasAligned] önceki karar.
  static bool resolve({required double delta, required bool wasAligned}) {
    final deviation = delta.abs();
    return wasAligned ? deviation <= exitDegrees : deviation <= enterDegrees;
  }

  /// Bir önceki farktan yenisine en kısa yoldan gidilen adım (−180…180).
  ///
  /// Ok animasyonu sürekli bir açı üzerinden döner; fark −179'dan 179'a
  /// atladığında bu adım +358 değil −2 olmalı, yoksa ok ters yönde tam tur atar.
  static double shortestStep({required double from, required double to}) {
    var step = to - from;
    if (step > 180) step -= 360;
    if (step < -180) step += 360;
    return step;
  }
}
