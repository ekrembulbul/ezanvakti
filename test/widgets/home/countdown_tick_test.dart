import 'package:ezanvakti/presentation/widgets/home/countdown_hero.dart';
import 'package:flutter_test/flutter_test.dart';

/// Geri sayimin gosterdigi deger, hedef vaktin milisaniyesi sifir oldugu icin
/// (vakitler `DateTime(y, m, d, hour, minute)` ile kuruluyor) yalnizca duvar
/// saatinin saniyesine bagli: saniye degisince deger degisir, saniye icinde
/// hangi anda orneklendigi fark etmez.
///
/// Bu yuzden yenileme, serbest calisan bir periyodik timer ile degil, bir
/// sonraki saniye sinirina kilitlenerek yapilmali. Aksi halde ornekleme fazi
/// sinira yakin dustugunde ardisik iki ornek sinirin iki yanina duser: bir
/// deger iki kez cizilir (~2 sn ekranda kalir), komsusu hic cizilmez.
void main() {
  group('delayToNextSecond', () {
    test('Saniye ortasindan sinira kalan sure', () {
      final delay = delayToNextSecond(DateTime(2026, 8, 3, 12, 0, 30, 500));

      expect(delay, const Duration(milliseconds: 500) + kTickMargin);
    });

    test('Sinira cok yakinken kisa bekler', () {
      final delay = delayToNextSecond(DateTime(2026, 8, 3, 12, 0, 30, 999));

      expect(delay, const Duration(milliseconds: 1) + kTickMargin);
    });

    test('Kararli durumda periyot tam bir saniye', () {
      // Bir onceki tik sinirdan `kTickMargin` sonra dustuyse, bir sonraki
      // bekleme tam 1 sn olmali; aksi halde faz her turda kayar.
      final afterTick = DateTime(
        2026,
        8,
        3,
        12,
        0,
        30,
        kTickMargin.inMilliseconds,
      );

      expect(delayToNextSecond(afterTick), const Duration(seconds: 1));
    });

    test('Sinirin tam ustunde bir sonraki saniyeyi bekler', () {
      final delay = delayToNextSecond(DateTime(2026, 8, 3, 12, 0, 30, 0));

      expect(delay, const Duration(seconds: 1) + kTickMargin);
    });

    test('Bekleme her zaman pozitif ve bir saniyeyi asmaz', () {
      for (var ms = 0; ms < 1000; ms++) {
        final delay = delayToNextSecond(DateTime(2026, 8, 3, 12, 0, 30, ms));

        expect(delay, greaterThan(Duration.zero), reason: 'ms=$ms');
        expect(
          delay,
          lessThanOrEqualTo(const Duration(seconds: 1) + kTickMargin),
          reason: 'ms=$ms',
        );
      }
    });
  });
}
