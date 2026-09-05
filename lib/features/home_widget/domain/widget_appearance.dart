import '../../../core/models/appearance_settings.dart';

/// Widget'a gönderilen görünüm payload'ı.
///
/// Swift tarafındaki karşılığı `ios/WidgetCore/WidgetAppearance.swift`;
/// anahtar adları ve enum değerleri (`AppThemeMode.name`, `DayPhase.name`)
/// orada birebir okunuyor. Snapshot'tan ayrı bir anahtar altında yazılır:
/// tema değişince vakit verisini yeniden yazmak gerekmiyor.
Map<String, Object> widgetAppearanceJson(AppearanceSettings settings) => {
  'themeMode': settings.themeMode.name,
  'timeBasedColor': settings.timeBasedColor,
  'fixedPalette': settings.fixedPalette.name,
};
