import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'day_phase.dart';

/// Yüzey/kenarlık/ayıraç alfa değerleri sabittir; değişen yalnızca üzerine
/// bindirilen **mürekkep** rengidir. Koyu temada mürekkep her palette beyaz,
/// açık temada paletin kendi Metin1 rengidir — böylece kartlar gri değil,
/// zeminin renkli gölgesi olur.
/// Koyu temada kart yüzeyi ve kenarlığı mürekkep yıkamasıdır.
const double _surfaceAlpha = 0.05;
const double _borderAlpha = 0.07;

/// Açık temada kart **opak beyaz**, kenarlığı biraz daha belirgin. Mürekkep
/// yıkaması burada gri bir sis yaratıyordu; tasarım dört açık palette de
/// `#FFFFFF` + mürekkep %9 kullanıyor.
const Color _lightSurface = Color(0xFFFFFFFF);
const double _lightBorderAlpha = 0.09;

/// Segment yatağı her iki temada da mürekkep yıkaması (tasarım: %5 / %7).
const double _trackSurfaceAlpha = 0.05;
const double _trackBorderAlpha = 0.07;

const double _dividerAlpha = 0.09;
const double _secondarySurfaceAlpha = 0.04;

/// Cetvel yatağı: koyu temada %9, açık temada %12 (açık zeminde %9 kayboluyor).
const double _mutedTrackDarkAlpha = 0.09;
const double _mutedTrackLightAlpha = 0.12;

/// Kayan segmentte seçili hap: koyu temada accent %14, açık temada %11.
const double _selectedControlDarkAlpha = 0.14;
const double _selectedControlLightAlpha = 0.11;

/// Hap gölgesi yalnızca koyu temada var (siyah %35). Açık zeminde her gölge —
/// siyah da, paletin mürekkebi de — saydam hap'ın altında kirli gri bir leke
/// bırakıyordu; hap zaten accent dolgusu ve kenarlığıyla zeminden ayrışıyor.
const double _controlShadowDarkAlpha = 0.35;

/// Koyu temada mürekkep her palette beyazdır.
const Color _darkInk = Color(0xFFFFFFFF);

/// Açık temada mürekkep = paletin Metin1 rengi. [ink] bu yüzden ayrı bir
/// parametre değil, [textPrimary]'den türetilir.
AppTokens _palette({
  required Color accent,
  required Color ink,
  required Color textPrimary,
  required Color textSecondary,
  required Color textTertiary,
  required Color textValue,
  required List<Color> backgroundStops,
  required bool isDark,
}) {
  return AppTokens(
    accent: accent,
    surface: isDark ? ink.withValues(alpha: _surfaceAlpha) : _lightSurface,
    border: ink.withValues(alpha: isDark ? _borderAlpha : _lightBorderAlpha),
    trackSurface: ink.withValues(alpha: _trackSurfaceAlpha),
    trackBorder: ink.withValues(alpha: _trackBorderAlpha),
    divider: ink.withValues(alpha: _dividerAlpha),
    secondarySurface: ink.withValues(alpha: _secondarySurfaceAlpha),
    mutedTrack: ink.withValues(
      alpha: isDark ? _mutedTrackDarkAlpha : _mutedTrackLightAlpha,
    ),
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    textTertiary: textTertiary,
    textValue: textValue,
    selectedControl: accent.withValues(
      alpha: isDark ? _selectedControlDarkAlpha : _selectedControlLightAlpha,
    ),
    controlShadow: isDark
        ? const Color(0xFF000000).withValues(alpha: _controlShadowDarkAlpha)
        : Colors.transparent,
    backgroundStops: backgroundStops,
  );
}

/// Açık tema paleti: mürekkep [textPrimary]'den türetilir.
AppTokens _lightPalette({
  required Color accent,
  required Color textPrimary,
  required Color textSecondary,
  required Color textTertiary,
  required Color textValue,
  required List<Color> backgroundStops,
}) {
  return _palette(
    accent: accent,
    isDark: false,
    ink: textPrimary,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    textTertiary: textTertiary,
    textValue: textValue,
    backgroundStops: backgroundStops,
  );
}

// ── Koyu tema ───────────────────────────────────────────────────────────────

/// ÇİVİT — İmsak → Öğle.
final AppTokens _morningDark = _palette(
  accent: const Color(0xFF93C4E8),
  ink: _darkInk,
  isDark: true,
  textPrimary: const Color(0xFFE8F0F8),
  textSecondary: const Color(0xFFA5BDD2),
  textTertiary: const Color(0xFF8DA8C2),
  textValue: const Color(0xFFC4D7E8),
  backgroundStops: const [
    Color(0xFF2C5279),
    Color(0xFF143049),
    Color(0xFF08141F),
  ],
);

/// KURŞUNİ — Öğle → İkindi.
final AppTokens _afternoonDark = _palette(
  accent: const Color(0xFFD8E8EE),
  ink: _darkInk,
  isDark: true,
  textPrimary: const Color(0xFFF0F5F7),
  textSecondary: const Color(0xFFAFC3CB),
  textTertiary: const Color(0xFF98AEB7),
  textValue: const Color(0xFFCDDCE2),
  backgroundStops: const [
    Color(0xFF40525C),
    Color(0xFF202C33),
    Color(0xFF10171B),
  ],
);

/// ERGUVAN — İkindi → Yatsı.
final AppTokens _eveningDark = _palette(
  accent: const Color(0xFFE09FB8),
  ink: _darkInk,
  isDark: true,
  textPrimary: const Color(0xFFF3EEF4),
  textSecondary: const Color(0xFFB5A8C1),
  textTertiary: const Color(0xFFA294AF),
  textValue: const Color(0xFFCFC3D6),
  backgroundStops: const [
    Color(0xFF4A2144),
    Color(0xFF241634),
    Color(0xFF120E1B),
  ],
);

/// SÜMBÜL — Yatsı → İmsak.
final AppTokens _nightDark = _palette(
  accent: const Color(0xFFCDA6E4),
  ink: _darkInk,
  isDark: true,
  textPrimary: const Color(0xFFF2ECF6),
  textSecondary: const Color(0xFFB3A5C1),
  textTertiary: const Color(0xFF9D8FAB),
  textValue: const Color(0xFFD5C9DF),
  backgroundStops: const [
    Color(0xFF2A2038),
    Color(0xFF17111F),
    Color(0xFF0A080E),
  ],
);

// ── Açık tema ───────────────────────────────────────────────────────────────

/// NİLÜFER — İmsak → Öğle.
final AppTokens _morningLight = _lightPalette(
  accent: const Color(0xFF265F8E),
  textPrimary: const Color(0xFF0E1D2C),
  textSecondary: const Color(0xFF43596D),
  textTertiary: const Color(0xFF53697C),
  textValue: const Color(0xFF33495E),
  backgroundStops: const [
    Color(0xFFDCE9F7),
    Color(0xFFEDF3FA),
    Color(0xFFF8FBFD),
  ],
);

/// SEDEF — Öğle → İkindi.
final AppTokens _afternoonLight = _lightPalette(
  accent: const Color(0xFF2A5B68),
  textPrimary: const Color(0xFF0F1C21),
  textSecondary: const Color(0xFF435A62),
  textTertiary: const Color(0xFF536A72),
  textValue: const Color(0xFF334A52),
  backgroundStops: const [
    Color(0xFFE2ECF0),
    Color(0xFFF1F6F8),
    Color(0xFFF9FCFC),
  ],
);

/// GÜLKURUSU — İkindi → Yatsı.
///
/// Tasarımda mürekkep `#2D191E` idi ama Metin1 `#201A1E`; diğer üç palette
/// ikisi birebir aynı olduğu için sapma kurala uyduruldu. Görsel bedeli yok:
/// kırmızı kanalda 13/255 fark %9 alfayla bindiğinde ekrana 1.17/255 düşer.
///
/// Accent tasarımda `#9E4266` idi; ölçülen kontrastı 5.02:1, spec'in accent
/// eşiği 5.1:1. Her kanal 0.96 ile çarpılarak `#983F62`'ye indirildi → 5.33:1.
/// Ton korunuyor; sekiz paletin tek eşik ihlali böyle kapandı.
final AppTokens _eveningLight = _lightPalette(
  accent: const Color(0xFF983F62),
  textPrimary: const Color(0xFF201A1E),
  textSecondary: const Color(0xFF5A4A50),
  textTertiary: const Color(0xFF6B5A60),
  textValue: const Color(0xFF4A3B41),
  backgroundStops: const [
    Color(0xFFF7E7EB),
    Color(0xFFFAF2F4),
    Color(0xFFFDFAFA),
  ],
);

/// LEYLAK — Yatsı → İmsak.
final AppTokens _nightLight = _lightPalette(
  accent: const Color(0xFF5E3A80),
  textPrimary: const Color(0xFF1A1424),
  textSecondary: const Color(0xFF4F4260),
  textTertiary: const Color(0xFF5F5270),
  textValue: const Color(0xFF3F3350),
  backgroundStops: const [
    Color(0xFFEBE4F1),
    Color(0xFFF7F4F9),
    Color(0xFFFCFBFD),
  ],
);

/// Verilen dilim ve parlaklık için paleti döner.
AppTokens paletteFor(DayPhase phase, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return switch (phase) {
    DayPhase.morning => isDark ? _morningDark : _morningLight,
    DayPhase.afternoon => isDark ? _afternoonDark : _afternoonLight,
    DayPhase.evening => isDark ? _eveningDark : _eveningLight,
    DayPhase.night => isDark ? _nightDark : _nightLight,
  };
}
