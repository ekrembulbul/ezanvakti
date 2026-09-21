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

/// Kerahatte dolgulu bant: beyaz çubuk, karartılmış yatak, bordo gölge.
const double _kActiveFillAlpha = 0.85;
const double _kActiveTrackAlpha = 0.20;
const double _kActiveShadowAlpha = 0.35;

/// Sayacın altındaki tam genişlik kerahat bandı.
///
/// Ortada tek satır: ikon · kelime · sayaç, kelime ve sayaç aynı punto.
/// Yaklaşırken kelime "Kerahate" ve sayaç başlangıca sayar — "Kerahat 13:41"
/// kerahatin sürdüğü gibi okunuyordu (2026-09-21); kerahatte "Kerahat" ve
/// sayaç bitişe sayar (dk:sn). Büyük sayaç bundan bağımsız, sıradaki vakte
/// sayar. Yaklaşırken turuncu çerçeveli ve çubuksuz; kerahatte bordo dolgulu,
/// altındaki çubuk aralığın geçen kısmını gösterir. Saati ve yeniden çizimi
/// `CountdownHero` verir; bant kendi zamanlayıcısını tutmaz.
class KerahatBand extends StatelessWidget {
  final KerahatStatus status;
  final DateTime now;

  const KerahatBand({super.key, required this.status, required this.now});

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
    final label = isActive
        ? context.l10n.kerahatBandLabel
        : context.l10n.kerahatSoonBandLabel;

    return Container(
      key: kKerahatBandKey,
      // Çubuklu bantta alt pay çubuğun görsel ağırlığı için 2 az; çubuksuzda
      // satır dikeyde tam ortada.
      padding: isActive
          ? const EdgeInsets.fromLTRB(16, 12, 16, 10)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
                Icon(Icons.wb_twilight_rounded, size: 22, color: foreground),
                const SizedBox(width: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: AppTypography.kerahatBandLabel.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  remaining,
                  key: kKerahatBandCountdownKey,
                  style: AppTypography.kerahatBandValue.copyWith(
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 8),
            _ProgressBar(
              progress: activeProgress(interval, now),
              fill: Colors.white.withValues(alpha: _kActiveFillAlpha),
              track: Colors.black.withValues(alpha: _kActiveTrackAlpha),
            ),
          ],
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
