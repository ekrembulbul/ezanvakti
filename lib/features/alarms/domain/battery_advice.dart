import '../../../core/services/device_settings_service.dart';

/// Pil optimizasyonu uyarısının kararı.
///
/// Android'in kendi pil tasarrufu alarm saatini (`setAlarmClock`)
/// geciktirmiyor; sorun bazı üreticilerin ek uyutma sistemlerinde. Uyarı
/// yalnız bu markalarda çıkar (dontkillmyapp.com'daki yaygın vakalar);
/// liste gerçek cihaz testinde güncellenir.
class BatteryAdvice {
  const BatteryAdvice._();

  static const String dismissedKey = 'battery_warning_dismissed';

  static const Set<String> aggressiveBrands = {
    'xiaomi',
    'redmi',
    'poco',
    'samsung',
    'huawei',
    'honor',
    'oneplus',
    'oppo',
    'vivo',
    'realme',
    'meizu',
    'asus',
    'tecno',
    'infinix',
  };

  static bool shouldWarn({
    required BatteryStatus status,
    required bool dismissed,
    required bool hasActiveAlarm,
  }) {
    if (dismissed || !hasActiveAlarm || status.ignoringOptimizations) {
      return false;
    }
    return aggressiveBrands.contains(status.manufacturer) ||
        aggressiveBrands.contains(status.brand);
  }
}
