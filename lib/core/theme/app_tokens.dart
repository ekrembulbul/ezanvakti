import 'package:flutter/material.dart';

/// Tek bir paletin tüm renk token'ları.
///
/// Widget'lar renk sabiti yazmaz; `context.tokens` üzerinden okur. [lerp]
/// sayesinde palet değişimi `AnimatedTheme` ile yumuşatılabilir.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  /// Vurgu rengi. Yalnızca vakit bilgisi ve tek birincil eylem kullanır.
  final Color accent;

  /// Grup/kart yüzeyi.
  final Color surface;

  /// Kart kenarlığı.
  final Color border;

  /// Satır ayıracı.
  final Color divider;

  /// "Yarın" satırı gibi ikincil yüzeyler.
  final Color secondarySurface;

  /// Cetvel yatağı gibi pasif şeritler.
  final Color mutedTrack;

  /// Birincil metin: başlıklar.
  final Color textPrimary;

  /// İkincil metin: açıklamalar.
  final Color textSecondary;

  /// Etiketler, pasif sekme, ızgaradaki vakit adları.
  final Color textTertiary;

  /// Liste ve ızgaradaki saat değerleri.
  final Color textValue;

  /// Zemin radial gradyanının üç durağı (%0, %44, %100).
  final List<Color> backgroundStops;

  const AppTokens({
    required this.accent,
    required this.surface,
    required this.border,
    required this.divider,
    required this.secondarySurface,
    required this.mutedTrack,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textValue,
    required this.backgroundStops,
  });

  /// Zemin gradyanı. Geometri her palette aynıdır, yalnızca renkler değişir.
  /// Tasarımdaki CSS karşılığı: `radial-gradient(125% 58% at 70% -4%, ...)`.
  RadialGradient get backgroundGradient => RadialGradient(
    center: const Alignment(0.40, -1.08),
    radius: 1.25,
    colors: backgroundStops,
    stops: const [0.0, 0.44, 1.0],
  );

  @override
  AppTokens copyWith({
    Color? accent,
    Color? surface,
    Color? border,
    Color? divider,
    Color? secondarySurface,
    Color? mutedTrack,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textValue,
    List<Color>? backgroundStops,
  }) {
    return AppTokens(
      accent: accent ?? this.accent,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      secondarySurface: secondarySurface ?? this.secondarySurface,
      mutedTrack: mutedTrack ?? this.mutedTrack,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textValue: textValue ?? this.textValue,
      backgroundStops: backgroundStops ?? this.backgroundStops,
    );
  }

  @override
  AppTokens lerp(covariant ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      accent: Color.lerp(accent, other.accent, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      secondarySurface: Color.lerp(
        secondarySurface,
        other.secondarySurface,
        t,
      )!,
      mutedTrack: Color.lerp(mutedTrack, other.mutedTrack, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textValue: Color.lerp(textValue, other.textValue, t)!,
      backgroundStops: [
        for (var i = 0; i < backgroundStops.length; i++)
          Color.lerp(backgroundStops[i], other.backgroundStops[i], t)!,
      ],
    );
  }
}
