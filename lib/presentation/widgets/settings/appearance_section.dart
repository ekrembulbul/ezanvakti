import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/appearance_settings.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/day_phase.dart';
import '../../../core/theme/palettes.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/tokens_context.dart';
import '../common/sliding_segment.dart';

/// Ayarlar → Görünüm bölümü.
///
/// Tema modu ve "vakte göre renk" ayarlarının tek kullanıcı arayüzü.
/// Palet şeridi, anahtar **kapalıyken** seçici olur: sabit renk bir kimlik
/// tercihidir, uygulamanın dayatması değil.
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final tokens = context.tokens;
    final settings = controller.settings;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tema',
            style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
          ),
          const SizedBox(height: 12),
          SlidingSegment<AppThemeMode>(
            items: const [
              SegmentItem(value: AppThemeMode.dark, label: 'Koyu'),
              SegmentItem(value: AppThemeMode.light, label: 'Açık'),
              SegmentItem(value: AppThemeMode.system, label: 'Sistem'),
            ],
            selected: settings.themeMode,
            onChanged: controller.setThemeMode,
            height: 40,
            radius: 12,
            padding: 3,
          ),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: 1, color: tokens.divider),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vakte göre renk',
                      style: AppTypography.rowTitle.copyWith(
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      settings.timeBasedColor
                          ? 'Zemin gün içinde ilerler'
                          : 'Sabit bir palet seçin',
                      style: AppTypography.rowSubtitle.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.timeBasedColor,
                onChanged: controller.setTimeBasedColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PaletteStrip(controller: controller),
        ],
      ),
    );
  }
}

/// Dört paletin önizleme şeridi. Anahtar kapalıyken seçici.
class _PaletteStrip extends StatelessWidget {
  final ThemeController controller;

  const _PaletteStrip({required this.controller});

  /// Anahtar açıkken o anki dilim, kapalıyken kullanıcının seçtiği palet
  /// çerçeveyle işaretlenir. İkisi de [ThemeController.phase]'ten gelir.
  bool _isMarked(DayPhase phase) => controller.phase == phase;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final selectable = !controller.settings.timeBasedColor;

    return Row(
      children: [
        for (final phase in DayPhase.values) ...[
          if (phase != DayPhase.values.first) const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              key: Key('palette_swatch_${phase.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: selectable
                  ? () => controller.setFixedPalette(phase)
                  : null,
              child: Container(
                height: 34,
                decoration: BoxDecoration(
                  gradient: paletteFor(
                    phase,
                    controller.brightness,
                  ).backgroundGradient,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: _isMarked(phase)
                        ? tokens.accent
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
