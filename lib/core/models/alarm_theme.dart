import 'package:flutter/material.dart';

import '../theme/day_phase.dart';
import '../theme/palettes.dart';

/// Çalar ekranın paletini belirleyen görünüm girdisi.
///
/// `ThemeController`'ın aynı anki durumunun kopyası. Alarm planlama katmanı
/// (domain) tema denetleyicisine bağlanmasın diye araya bu değer nesnesi
/// giriyor; test etmek de kolaylaşıyor.
class AlarmAppearance {
  /// Kullanıcının seçtiği tema; `system` ise cihazın o anki tercihi.
  final Brightness brightness;

  /// Kapalıysa palet vakte göre ilerlemez, [fixedPalette] kullanılır.
  final bool timeBasedColor;

  final DayPhase fixedPalette;

  const AlarmAppearance({
    required this.brightness,
    required this.timeBasedColor,
    required this.fixedPalette,
  });

  /// Görünüm bilgisi yoksa (ör. testte) uygulamanın kurulum varsayılanı.
  static const AlarmAppearance fallback = AlarmAppearance(
    brightness: Brightness.dark,
    timeBasedColor: true,
    fixedPalette: fallbackDayPhase,
  );
}

/// Native çalar ekranının renkleri: Android'de tam ekran Activity'nin zemini ve
/// vurgusu, iOS'ta AlarmKit uyarısının `tintColor`'ı.
///
/// Palet, kullanıcının görünüm ayarlarına uyar: koyu/açık tema seçimi
/// korunur ve "vakte göre renk" kapalıysa seçtiği sabit palet kullanılır.
/// Açıkken palet alarmın **çalacağı** anın dilimine göre seçilir; sabah alarmı
/// ÇİVİT, yatsı alarmı SÜMBÜL ile çalar.
class AlarmTheme {
  final Color accent;

  /// Zemin gradyanının üstten alta üç durağı.
  final List<Color> backgroundStops;

  final Color textPrimary;
  final Color textSecondary;

  const AlarmTheme({
    required this.accent,
    required this.backgroundStops,
    required this.textPrimary,
    required this.textSecondary,
  });

  factory AlarmTheme.forPalette(DayPhase phase, Brightness brightness) {
    final tokens = paletteFor(phase, brightness);
    return AlarmTheme(
      accent: tokens.accent,
      backgroundStops: tokens.backgroundStops,
      textPrimary: tokens.textPrimary,
      textSecondary: tokens.textSecondary,
    );
  }

  /// Görünüm ayarı ve (vakte göre renk açıksa) çalma anının dilimi.
  factory AlarmTheme.resolve({
    required AlarmAppearance appearance,
    required DayPhase phaseAtFire,
  }) {
    final phase = appearance.timeBasedColor
        ? phaseAtFire
        : appearance.fixedPalette;
    return AlarmTheme.forPalette(phase, appearance.brightness);
  }

  /// Platform channel gösterimi. Renkler `#RRGGBB`; hem `Color.parseColor`
  /// (Android) hem de iOS tarafındaki ayrıştırıcı bu biçimi okur.
  Map<String, dynamic> toMap() {
    return {
      'accent': _hex(accent),
      'backgroundStops': backgroundStops.map(_hex).toList(),
      'textPrimary': _hex(textPrimary),
      'textSecondary': _hex(textSecondary),
    };
  }

  static String _hex(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
