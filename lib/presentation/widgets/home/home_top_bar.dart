import 'package:flutter/material.dart';
import '../../../l10n/l10n_extensions.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/hijri_formatter.dart';

/// Ana ekranın üst çubuğu: konum · ayarlar.
///
/// Uygulama ikonu ekranda gösterilmez; yalnızca launcher ve açılış ekranında
/// kullanılır. Ayarlar girişi yalnızca burada; Takvim ve Hatırlatıcılar
/// sekmelerinin başlıkları temiz kalır (spec D5).
class HomeTopBar extends StatelessWidget {
  final String locationName;
  final VoidCallback? onLocationTap;
  final VoidCallback onSettingsTap;

  /// Arka planda vakit yenilemesi sürerken ince bir gösterge çizilir.
  final bool isRefreshing;

  const HomeTopBar({
    super.key,
    required this.locationName,
    required this.onLocationTap,
    required this.onSettingsTap,
    this.isRefreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // Gösterge `Positioned` olduğu için satır yüksekliği değişmez; yenileme
    // başlayıp bitince ekranın geri kalanı kaymaz.
    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          Row(
            // `Spacer` yerine spaceBetween: Spacer da flex:1 oldugu icin bos
            // alani konum etiketiyle yariya bolup ayarlar ikonunu sagdan
            // iceri kaydiriyordu.
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onLocationTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          locationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.rowTitle.copyWith(
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        Icons.expand_more_rounded,
                        size: 18,
                        color: tokens.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSettingsTap,
                child: Icon(
                  Icons.settings_rounded,
                  size: 22,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
          if (isRefreshing)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: tokens.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Üst çubuğun altındaki ortalanmış tarih satırı: miladi · hicri.
class HomeDateLine extends StatelessWidget {
  final DateTime date;

  const HomeDateLine({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final gregorian = DateFormat(
      'EEEE, d MMMM y',
      Localizations.localeOf(context).toLanguageTag(),
    ).format(date);

    return SizedBox(
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              gregorian,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.dateLine.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: tokens.textTertiary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            HijriFormatter.format(date, context.l10n),
            style: AppTypography.dateLine.copyWith(color: tokens.accent),
          ),
        ],
      ),
    );
  }
}
