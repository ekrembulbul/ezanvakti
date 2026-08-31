import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Cihazın baktığı yön.
class HeadingReading {
  /// Kuzeyden saat yönünde 0–360°. Mümkünse **gerçek** kuzeye göre; cihaz
  /// gerçek kuzeyi bilmiyorsa manyetik kuzey.
  final double degrees;

  /// Sapma payı (derece). Negatif değer "yön geçersiz" demek — iOS
  /// kalibrasyon gerektiğinde bunu döner.
  final double accuracy;

  const HeadingReading({required this.degrees, required this.accuracy});

  /// Bu eşiğin üstünde okuma güvenilmez sayılır; kullanıcıdan cihazı sekiz
  /// çizerek kalibre etmesi istenir.
  static const double calibrationThreshold = 25;

  bool get needsCalibration =>
      accuracy < 0 || accuracy > calibrationThreshold;

  /// Native olayını okumaya çevirir; alanlar eksik ya da bozuksa `null`.
  static HeadingReading? fromMap(Object? event) {
    if (event is! Map) return null;
    final degrees = event['degrees'];
    final accuracy = event['accuracy'];
    if (degrees is! num || accuracy is! num) return null;
    return HeadingReading(
      degrees: degrees.toDouble(),
      accuracy: accuracy.toDouble(),
    );
  }
}

/// Cihazın pusula yönünü native taraftan akıtır.
///
/// Yeni bir paket eklemek yerine tek bir `EventChannel` yazıldı: iOS'ta
/// `CLLocationManager` gerçek kuzeyi (true heading) veriyor; hazır paketlerin
/// çoğu yalnızca manyetik kuzey döndürüyor ve kıble hesabı için manyetik
/// sapma düzeltmesi gerekiyor.
class HeadingService {
  static const EventChannel _channel = EventChannel(
    'com.ekrembulbul.ezanvakti/heading',
  );

  const HeadingService();

  bool get _hasNative =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  /// Yön akışı. Desteklenmeyen platformda boş akış döner — çağıran ekran
  /// "pusula kullanılamıyor" durumunu gösterir.
  ///
  /// Bozuk olaylar sessizce atlanır: tek bir geçersiz kare akışı kapatmamalı.
  Stream<HeadingReading> get headings {
    if (!_hasNative) return const Stream<HeadingReading>.empty();
    return _channel
        .receiveBroadcastStream()
        .map(HeadingReading.fromMap)
        .where((reading) => reading != null)
        .cast<HeadingReading>();
  }
}
