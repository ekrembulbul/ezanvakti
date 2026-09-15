import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../core/utils/turkish_suffix.dart';
import '../../../features/prayer_times/domain/kerahat_status.dart';
import '../../../features/prayer_times/domain/kerahat_times.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../utils/time_format_context.dart';

const Key kKerahatBandKey = Key('kerahat_band');
const Key kKerahatBandFillKey = Key('kerahat_band_fill');

const double _kRadius = 14;
const double _kBarHeight = 4;

/// Yaklaşırken çubuğun yatağı: metin renginin soluk hâli.
const double _kTrackAlpha = 0.16;

/// Kerahatte dolgulu bant: beyaz çubuk, karartılmış yatak, bordo gölge.
const double _kActiveFillAlpha = 0.85;
const double _kActiveTrackAlpha = 0.20;
const double _kActiveShadowAlpha = 0.35;

/// Tarih satırının altındaki tam genişlik kerahat bandı.
///
/// İki durum, iki ağırlık: yaklaşırken çerçeveli ve açık zeminli, kerahatte
/// dolgulu. Çubuk yaklaşırken 30 dakikalık uyarı penceresinin, kerahatte
/// aralığın geçen kısmını gösterir. Saati ve yeniden çizimi `CountdownHero`
/// verir; bant kendi zamanlayıcısını tutmaz.
class KerahatBand extends StatelessWidget {
  final KerahatStatus status;
  final DateTime now;

  const KerahatBand({super.key, required this.status, required this.now});

  /// Uyarı penceresinin geçen kısmı (0..1).
  static double approachingProgress(KerahatInterval interval, DateTime now) {
    final remaining = interval.start.difference(now).inSeconds;
    return (1 - remaining / KerahatWarning.lead.inSeconds).clamp(0.0, 1.0);
  }

  /// Aralığın geçen kısmı (0..1); bozuk aralıkta 0.
  static double activeProgress(KerahatInterval interval, DateTime now) {
    final total = interval.end.difference(interval.start).inSeconds;
    if (total <= 0) return 0;
    return (now.difference(interval.start).inSeconds / total).clamp(0.0, 1.0);
  }

  /// Başlangıç saati; Türkçede bulunma ekiyle ("18:38'de"). Ek yalnız tr'de
  /// anlamlı olduğundan mesaja değil buraya konur: ARB yer tutucuları her
  /// dilde aynı kalır.
  static String _startLabel(BuildContext context, DateTime start) {
    final time = context.formatTime(start);
    if (Localizations.localeOf(context).languageCode != 'tr') return time;
    return time + turkishLocativeSuffix(hour: start.hour, minute: start.minute);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final interval = status.interval;
    final isActive = status is KerahatActive;
    final foreground = isActive ? Colors.white : tokens.kerahatText;
    final text = isActive
        ? l10n.kerahatActiveLine(context.formatTime(interval.end))
        : l10n.kerahatStartsAt(_startLabel(context, interval.start));
    final remaining = formatCompactDuration(
      (isActive ? interval.end : interval.start).difference(now),
      l10n,
    );
    final progress = isActive
        ? activeProgress(interval, now)
        : approachingProgress(interval, now);

    return Container(
      key: kKerahatBandKey,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: isActive ? tokens.kerahatLine : tokens.kerahatSurface,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: tokens.kerahatLine),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: tokens.kerahatLine.withValues(
                    alpha: _kActiveShadowAlpha,
                  ),
                  blurRadius: 28,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.wb_twilight_rounded, size: 16, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.rowSubtitle.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                      fontVariations: const [FontVariation('wght', 600)],
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                remaining,
                style: AppTypography.hint.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation('wght', 700)],
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ProgressBar(
            progress: progress,
            fill: isActive
                ? Colors.white.withValues(alpha: _kActiveFillAlpha)
                : tokens.kerahatText,
            track: isActive
                ? Colors.black.withValues(alpha: _kActiveTrackAlpha)
                : tokens.kerahatText.withValues(alpha: _kTrackAlpha),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final Color fill;
  final Color track;

  const _ProgressBar({
    required this.progress,
    required this.fill,
    required this.track,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_kBarHeight / 2),
      child: SizedBox(
        height: _kBarHeight,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              heightFactor: 1,
              child: ColoredBox(key: kKerahatBandFillKey, color: fill),
            ),
          ],
        ),
      ),
    );
  }
}
