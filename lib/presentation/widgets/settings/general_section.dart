import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/general_settings.dart';
import '../../../core/providers/app_state.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/time_formatter.dart';
import '../common/sliding_segment.dart';

/// Ayarlar → Genel bölümünün tercih kartı: saat biçimi ve otomatik konum.
///
/// Değişiklik hem [AppState]'e (anında arayüz) hem depoya yazılır.
class GeneralSection extends StatelessWidget {
  const GeneralSection({super.key});

  Future<void> _update(BuildContext context, GeneralSettings next) async {
    context.read<AppState>().setGeneralSettings(next);
    await ServiceLocator().get<LocalStorage>().saveGeneralSettings(next);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final settings = context.watch<AppState>().generalSettings;

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
            'Saat biçimi',
            style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
          ),
          const SizedBox(height: 12),
          SlidingSegment<TimeFormatPreference>(
            items: [
              for (final preference in TimeFormatPreference.values)
                SegmentItem(value: preference, label: preference.label),
            ],
            selected: settings.timeFormat,
            onChanged: (value) =>
                _update(context, settings.copyWith(timeFormat: value)),
            height: 40,
            radius: 12,
            padding: 3,
          ),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: 1, color: tokens.divider),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Konumu otomatik izle',
                      style: AppTypography.rowTitle.copyWith(
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Şehir değişince vakitler kendiliğinden güncellenir.',
                      style: AppTypography.hint.copyWith(
                        color: tokens.textTertiary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.autoLocation,
                activeThumbColor: tokens.accent,
                onChanged: (value) =>
                    _update(context, settings.copyWith(autoLocation: value)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
