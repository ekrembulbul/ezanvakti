import 'dart:io';

import 'package:flutter/services.dart';

import '../models/quiet_interval.dart';
import '../utils/app_logger.dart';

/// Pil optimizasyonu durumu; üretici ve marka küçük harfle gelir.
class BatteryStatus {
  final String manufacturer;
  final String brand;
  final bool ignoringOptimizations;

  const BatteryStatus({
    required this.manufacturer,
    required this.brand,
    required this.ignoringOptimizations,
  });

  /// Bilinmeyen durum: uyarı gösterilmesin.
  static const BatteryStatus unknown = BatteryStatus(
    manufacturer: '',
    brand: '',
    ignoringOptimizations: true,
  );
}

/// Android cihaz ayarları ve izinleri: tam ekran alarm izni, pil
/// optimizasyonu, Rahatsız Etme erişimi ve sessiz pencere planı.
///
/// Android dışında ve native hata durumunda güvenli varsayılan döner:
/// uyarı göstermemek, kullanıcıyı yanlış bir uyarıyla rahatsız etmekten iyidir.
class DeviceSettingsService {
  static const MethodChannel _channel = MethodChannel(
    'com.ekrembulbul.ezanvakti/device',
  );

  final bool isAndroid;
  final AppLogger _logger;

  DeviceSettingsService({bool? isAndroid, AppLogger? logger})
    : isAndroid = isAndroid ?? Platform.isAndroid,
      _logger = logger ?? AppLogger();

  /// Android 14+: kapalıysa alarm kilit ekranında açılmaz.
  Future<bool> canUseFullScreenIntent() =>
      _bool('canUseFullScreenIntent', fallback: true);

  Future<void> openFullScreenIntentSettings() =>
      _call('openFullScreenIntentSettings');

  Future<BatteryStatus> batteryStatus() async {
    if (!isAndroid) return BatteryStatus.unknown;
    try {
      final map = await _channel.invokeMapMethod<String, Object?>(
        'batteryStatus',
      );
      if (map == null) return BatteryStatus.unknown;
      return BatteryStatus(
        manufacturer: (map['manufacturer'] as String? ?? '').toLowerCase(),
        brand: (map['brand'] as String? ?? '').toLowerCase(),
        ignoringOptimizations: map['ignoringOptimizations'] as bool? ?? true,
      );
    } on PlatformException catch (error) {
      _logger.warning('Battery status unavailable', error.code);
      return BatteryStatus.unknown;
    }
  }

  Future<void> openBatteryOptimizationSettings() =>
      _call('openBatteryOptimizationSettings');

  /// Telefonu susturma Android 10 (API 29) ve sonrasında var.
  Future<bool> isQuietModeSupported() =>
      _bool('isQuietModeSupported', fallback: false);

  Future<bool> hasQuietModeAccess() =>
      _bool('hasQuietModeAccess', fallback: false);

  Future<void> openQuietModeAccessSettings() =>
      _call('openQuietModeAccessSettings');

  /// Hata çağırana gider: planlayıcı loglayıp sürdürür.
  Future<void> setQuietSchedule(List<QuietInterval> intervals) async {
    if (!isAndroid) return;
    await _channel.invokeMethod<void>('setQuietSchedule', {
      'intervals': [for (final interval in intervals) interval.toMap()],
    });
  }

  Future<bool> _bool(String method, {required bool fallback}) async {
    if (!isAndroid) return fallback;
    try {
      return await _channel.invokeMethod<bool>(method) ?? fallback;
    } on PlatformException catch (error) {
      _logger.warning('Device call failed ($method)', error.code);
      return fallback;
    }
  }

  Future<void> _call(String method) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException catch (error) {
      _logger.warning('Device call failed ($method)', error.code);
    }
  }
}
