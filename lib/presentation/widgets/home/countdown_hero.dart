import 'dart:async';
import '../../../l10n/l10n_extensions.dart';
import '../../utils/time_format_context.dart';

import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../features/prayer_times/domain/kerahat_status.dart';
import '../../../features/prayer_times/domain/kerahat_times.dart';
import 'kerahat_band.dart';

/// Saniye sınırının ne kadar ardından uyanılacağı.
///
/// Tam sınırda uyanmak, timer'ın birkaç milisaniye erken tetiklenmesi
/// durumunda hâlâ bir önceki saniyede örnekleme yapma riski taşır.
const Duration kTickMargin = Duration(milliseconds: 20);

const Key kKerahatGlowKey = Key('kerahat_glow');

/// Parıltının sayaç kutusunu aşma payı; yerleşimi etkilemez.
const EdgeInsets _kGlowBleed = EdgeInsets.fromLTRB(40, 60, 40, 80);

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
/// Kerahat yaklaşırken ya da sürerken sayacın üstünde [KerahatBand] çizilir;
/// kerahatte sayaç kerahat rengine döner.
/// Büyük sayaç, `SONRAKİ · VAKİT` etiketinin gösterdiği zamana sayar.
class CountdownHero extends StatefulWidget {
  final DateTime nextPrayerTime;
  final String nextPrayerName;

  /// Başlık "İftara" gibi bir ifade olduğunda alt bilgideki vakit adı.
  final String? timeCaptionName;
  final List<KerahatInterval> kerahatIntervals;

  /// Sayaç ve kerahat durumu için ortak zaman kaynağı; varsayılan cihaz saati.
  final DateTime Function()? clock;

  const CountdownHero({
    super.key,
    required this.nextPrayerTime,
    required this.nextPrayerName,
    this.timeCaptionName,
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final now = _now();
    final status = KerahatWarning.resolve(widget.kerahatIntervals, now);
    final isActive = status is KerahatActive;
    final countdown = _countdown(
      context,
      now: now,
      color: isActive ? tokens.kerahatText : tokens.accent,
    );
    if (status == null) return countdown;

    // Bant tarih satırının altında, sayaçtan bağımsız tam genişlikte durur;
    // iki durum iki ağırlık. Kerahatte sayaç kerahat rengine döner ve arkasına
    // hafif parıltı gelir; hedefi yine sıradaki vakit.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KerahatBand(status: status, now: now),
        const SizedBox(height: 20),
        if (isActive) _withGlow(tokens.kerahatGlow, countdown) else countdown,
      ],
    );
  }

  /// Sayacın arkasındaki parıltı; kutusunu aşar, yerleşimi etkilemez.
  Widget _withGlow(Color glow, Widget countdown) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned(
          left: -_kGlowBleed.left,
          top: -_kGlowBleed.top,
          right: -_kGlowBleed.right,
          bottom: -_kGlowBleed.bottom,
          child: IgnorePointer(
            child: DecoratedBox(
              key: kKerahatGlowKey,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.1),
                  radius: 0.9,
                  colors: [
                    glow,
                    glow.withValues(alpha: glow.a * 0.47),
                    glow.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.45, 0.78],
                ),
              ),
            ),
          ),
        ),
        countdown,
      ],
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
          context.l10n.prayerTimeAt(
            widget.timeCaptionName ?? widget.nextPrayerName,
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
