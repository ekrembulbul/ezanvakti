import 'package:flutter/material.dart';

import '../theme/day_phase.dart';
import '../theme/palettes.dart';

/// Native çalar ekranının renkleri: Android'de tam ekran Activity'nin zemini ve
/// vurgusu, iOS'ta AlarmKit uyarısının `tintColor`'ı.
///
/// Palet, alarmın **çalacağı** anın dilimine göre seçilir; sabah alarmı ÇİVİT,
/// yatsı alarmı SÜMBÜL ile çalar. Uygulamanın "vakte göre renk" kimliği çalar
/// ekranında da sürüyor.
///
/// Her zaman koyu palet kullanılır: çalar ekran tam ekran açılır ve alarmların
/// çoğu karanlıkta çalar; açık palet bu anda göz alıyor.
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

  factory AlarmTheme.forPhase(DayPhase phase) {
    final tokens = paletteFor(phase, Brightness.dark);
    return AlarmTheme(
      accent: tokens.accent,
      backgroundStops: tokens.backgroundStops,
      textPrimary: tokens.textPrimary,
      textSecondary: tokens.textSecondary,
    );
  }

  /// Vakit verisi yokken kullanılan palet — uygulama ikonuyla aynı aile.
  factory AlarmTheme.fallback() => AlarmTheme.forPhase(fallbackDayPhase);

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
