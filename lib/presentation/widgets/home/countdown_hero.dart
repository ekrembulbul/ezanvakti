import 'dart:async';
import '../../utils/time_format_context.dart';

import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

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
/// Eski üç kutulu tasarımın yerini alır: tek satır `SS:DD:SS`, üstünde
/// `SONRAKİ · VAKİT` etiketi, altında vaktin saati.
class CountdownHero extends StatefulWidget {
  final DateTime nextPrayerTime;
  final String nextPrayerName;

  const CountdownHero({
    super.key,
    required this.nextPrayerTime,
    required this.nextPrayerName,
  });

  @override
  State<CountdownHero> createState() => _CountdownHeroState();
}

class _CountdownHeroState extends State<CountdownHero> {
  Timer? _timer;

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
    _timer = Timer(delayToNextSecond(DateTime.now()), () {
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

  String get _remaining {
    final raw = widget.nextPrayerTime.difference(DateTime.now());
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
    final time = context.formatTime(widget.nextPrayerTime);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'SONRAKİ',
              style: AppTypography.counterLabel.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              widget.nextPrayerName.replaceAll('i', 'İ').toUpperCase(),
              style: AppTypography.counterLabel.copyWith(color: tokens.accent),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _remaining,
            key: const Key('countdown_value'),
            style: AppTypography.counter.copyWith(color: tokens.accent),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "${widget.nextPrayerName} ezanı $time'de",
          style: AppTypography.heroSubtitle.copyWith(
            color: tokens.textSecondary,
          ),
        ),
      ],
    );
  }
}
