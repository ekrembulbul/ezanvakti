import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tokens.dart';
import 'app_typography.dart';

/// Uygulama temasının tek üretim noktası.
///
/// Renkler artık burada sabit değil; [AppTokens] içinden gelir ve gün dilimine
/// göre değişir. Widget'lar renk okumak için `context.tokens` kullanır.
class AppTheme {
  const AppTheme._();

  // ── Tema üretimi ──────────────────────────────────────────────────────────

  /// Verilen token setinden uygulama temasını üretir.
  ///
  /// Token'lar `extensions` içinde taşınır; `AnimatedTheme` palet değişimini
  /// [AppTokens.lerp] üzerinden yumuşatır.
  static ThemeData build(AppTokens tokens, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: tokens.backgroundStops.last,
      extensions: <ThemeExtension<dynamic>>[tokens],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: tokens.accent,
        onPrimary: tokens.backgroundStops.last,
        secondary: tokens.accent,
        onSecondary: tokens.backgroundStops.last,
        error: isDark ? const Color(0xFFEF9A9A) : const Color(0xFFB3261E),
        onError: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF),
        surface: tokens.backgroundStops.last,
        onSurface: tokens.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // AppBar ekrandayken kendi stilini uyguluyor ve main.dart'taki genel
        // ayari eziyor; ikisi ayni degeri vermeli.
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        centerTitle: true,
        titleTextStyle: AppTypography.screenTitle.copyWith(
          color: tokens.textPrimary,
        ),
        iconTheme: IconThemeData(color: tokens.textPrimary),
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.counter.copyWith(color: tokens.accent),
        titleLarge: AppTypography.screenTitle.copyWith(
          color: tokens.textPrimary,
        ),
        titleMedium: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
        bodyLarge: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
        bodyMedium: AppTypography.rowSubtitle.copyWith(
          color: tokens.textSecondary,
        ),
        bodySmall: AppTypography.hint.copyWith(color: tokens.textTertiary),
        labelSmall: AppTypography.sectionLabel.copyWith(
          color: tokens.textTertiary,
        ),
      ),
      dividerTheme: DividerThemeData(color: tokens.divider, thickness: 1),
      listTileTheme: ListTileThemeData(
        iconColor: tokens.accent,
        textColor: tokens.textPrimary,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: tokens.accent,
        foregroundColor: tokens.backgroundStops.last,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: tokens.backgroundStops.last,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: AppTypography.rowSubtitle.copyWith(
          color: tokens.textTertiary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? tokens.accent
              : tokens.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? tokens.accent.withValues(alpha: 0.3)
              : tokens.mutedTrack;
        }),
      ),
    );
  }
}
