import 'dart:async';
import '../../../l10n/l10n_extensions.dart';
import '../../utils/time_format_context.dart';

import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../features/prayer_times/domain/kerahat_times.dart';

/// Saniye sınırının ne kadar ardından uyanılacağı.
///
/// Tam sınırda uyanmak, timer'ın birkaç milisaniye erken tetiklenmesi
/// durumunda hâlâ bir önceki saniyede örnekleme yapma riski taşır.
const Duration kTickMargin = Duration(milliseconds: 20);

/// [now]'dan bir sonraki duvar saati saniye sınırına kalan süre (+[kTickMargin]).
///
/// Geri sayımın gösterdiği değer yalnızca duvar saatinin saniyesine bağlıdır:
/// hedef vaktin milisaniyesi sıfırdır (vakitler `DateTime(y, m, d, hour,
/// minute)` ile kurulur), dolayısıyla `floor(hedef − şimdi)` bir saniye
/// boyunca sabit kalır ve tam sınırda değişir. Yenileme bu sınıra kilitlenmezse
/// örnekleme fazı sınıra yakın düştüğünde ardışık iki örnek sınırın iki yanına
/// düşer: bir değer iki kez çizilir, komşusu hiç çizilmez.
Duration delayToNextSecond(DateTime now) {
  return Duration(milliseconds: 1000 - now.millisecond) + kTickMargin;
}

/// Ana ekranın ortalanmış geri sayım bloğu.
///
/// Aktif kerahatte başlık, bitiş saati ve kırmızı yüzeyle vurgulanır.
/// Büyük sayaç, `SONRAKİ · VAKİT` etiketinin gösterdiği ezana sayar.
class CountdownHero extends StatefulWidget {
  final DateTime nextPrayerTime;
  final String nextPrayerName;
  final List<KerahatInterval> kerahatIntervals;

  /// Sayaç ve kerahat durumu için ortak zaman kaynağı; varsayılan cihaz saati.
  final DateTime Function()? clock;

  const CountdownHero({
    super.key,
    required this.nextPrayerTime,
    required this.nextPrayerName,
    this.kerahatIntervals = const [],
    this.clock,
  });

  @override
  State<CountdownHero> createState() => _CountdownHeroState();
}

class _CountdownHeroState extends State<CountdownHero> {
  Timer? _timer;

  DateTime _now() => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  /// Bir sonraki saniye sınırına kilitli tek seferlik tik; her uyanışta
  /// yeniden kurulur. `Timer.periodic` yerine bunun kullanılmasının nedeni
  /// [delayToNextSecond] belgesinde.
  ///
  /// Tik yalnızca bu widget'ı yeniden çizer, ekranın tamamını değil.
  void _scheduleTick() {
    _timer?.cancel();
    _timer = Timer(delayToNextSecond(_now()), () {
      if (!mounted) return;
      setState(() {});
      _scheduleTick();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _remaining(DateTime now) {
    final raw = widget.nextPrayerTime.difference(now);
    // Vakit geçtiğinde üst katman kısa süre sonra sonraki vakti hesaplar;
    // arada negatif değer gösterilmez.
    final left = raw.isNegative ? Duration.zero : raw;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(left.inHours)}:${two(left.inMinutes.remainder(60))}:'
        '${two(left.inSeconds.remainder(60))}';
  }

  KerahatInterval? _activeKerahat(DateTime now) {
    for (final interval in widget.kerahatIntervals) {
      if (interval.contains(now)) return interval;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final now = _now();
    final active = _activeKerahat(now);
    final countdown = _countdown(
      context,
      now: now,
      color: active == null ? tokens.accent : tokens.kerahatText,
    );
    if (active == null) return countdown;

    return Container(
      key: const Key('kerahat_active_hero'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: tokens.kerahatSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.kerahatLine),
        boxShadow: [
          BoxShadow(
            color: tokens.kerahatLine.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 24,
                      color: tokens.kerahatText,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.l10n.kerahatActiveTitle,
                        textAlign: TextAlign.center,
                        style: AppTypography.reminderPrimary.copyWith(
                          color: tokens.kerahatText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.kerahatEndsAt(context.formatTime(active.end)),
                  textAlign: TextAlign.center,
                  style: AppTypography.rowSubtitle.copyWith(
                    color: tokens.kerahatText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          countdown,
        ],
      ),
    );
  }

  Widget _countdown(
    BuildContext context, {
    required DateTime now,
    required Color color,
  }) {
    final tokens = context.tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 9,
          runSpacing: 4,
          children: [
            Text(
              context.l10n.nextLabel,
              style: AppTypography.counterLabel.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            Text(
              widget.nextPrayerName.replaceAll('i', 'İ').toUpperCase(),
              textAlign: TextAlign.center,
              style: AppTypography.counterLabel.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _remaining(now),
            key: const Key('countdown_value'),
            style: AppTypography.counter.copyWith(color: color),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.adhanAt(
            widget.nextPrayerName,
            context.formatTime(widget.nextPrayerTime),
          ),
          textAlign: TextAlign.center,
          style: AppTypography.heroSubtitle.copyWith(
            color: tokens.textSecondary,
          ),
        ),
      ],
    );
  }
}
