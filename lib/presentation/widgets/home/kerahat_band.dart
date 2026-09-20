import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../features/prayer_times/domain/kerahat_status.dart';
import '../../../features/prayer_times/domain/kerahat_times.dart';
import '../../../l10n/l10n_extensions.dart';

const Key kKerahatBandKey = Key('kerahat_band');
const Key kKerahatBandFillKey = Key('kerahat_band_fill');
const Key kKerahatBandCountdownKey = Key('kerahat_band_countdown');

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
/// Ortada tek satır: ikon · "Kerahat" · sayaç. Sayaç yaklaşırken başlangıca,
/// kerahatte bitişe saniye saniye sayar (dk:sn); büyük sayaç bundan
/// bağımsız, sıradaki vakte sayar. Yaklaşırken turuncu çerçeveli, kerahatte
/// bordo dolgulu. Çubuk yaklaşırken 30 dakikalık uyarı penceresinin,
/// kerahatte aralığın geçen kısmını gösterir. Saati ve yeniden çizimi
/// `CountdownHero` verir; bant kendi zamanlayıcısını tutmaz.
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final interval = status.interval;
    final isActive = status is KerahatActive;
    final foreground = isActive ? Colors.white : tokens.kerahatSoonText;
    final remaining = formatMinutesSeconds(
      (isActive ? interval.end : interval.start).difference(now),
    );
    final progress = isActive
        ? activeProgress(interval, now)
        : approachingProgress(interval, now);

    return Container(
      key: kKerahatBandKey,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: isActive ? tokens.kerahatLine : tokens.kerahatSoonSurface,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(
          color: isActive ? tokens.kerahatLine : tokens.kerahatSoonLine,
        ),
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
          // Satır büyük metin ölçeğinde sığmazsa kırpmak yerine küçülür:
          // "Kerahat" yarım kalmasın, sayaç hep görünsün.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wb_twilight_rounded, size: 16, color: foreground),
                const SizedBox(width: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    context.l10n.kerahatBandLabel,
                    maxLines: 1,
                    style: AppTypography.rowSubtitle.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                      fontVariations: const [FontVariation('wght', 600)],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  remaining,
                  key: kKerahatBandCountdownKey,
                  style: AppTypography.heroSubtitle.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    fontVariations: const [FontVariation('wght', 700)],
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _ProgressBar(
            progress: progress,
            fill: isActive
                ? Colors.white.withValues(alpha: _kActiveFillAlpha)
                : tokens.kerahatSoonText,
            track: isActive
                ? Colors.black.withValues(alpha: _kActiveTrackAlpha)
                : tokens.kerahatSoonText.withValues(alpha: _kTrackAlpha),
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
