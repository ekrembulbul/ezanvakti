import 'package:flutter/material.dart';
import '../../../l10n/l10n_extensions.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/hijri_formatter.dart';

const Key kHomeGpsIconKey = Key('home_gps_icon');

/// Ana ekranın üst çubuğu: konum · takvim · kerahat ayrıntıları · ayarlar.
///
/// Uygulama ikonu ekranda gösterilmez; yalnızca launcher ve açılış ekranında
/// kullanılır. Ayarlar girişi yalnızca burada; Takvim ve Hatırlatıcılar
/// sekmelerinin başlıkları temiz kalır (spec D5).
class HomeTopBar extends StatelessWidget {
  final String locationName;
  final VoidCallback? onLocationTap;
  final VoidCallback onSettingsTap;
  final VoidCallback? onKerahatTap;

  /// Arka planda vakit yenilemesi sürerken ince bir gösterge çizilir.
  final bool isRefreshing;

  /// Konum cihazdan (GPS) geliyorsa adın önüne hedef ikonu çizilir; kullanıcı
  /// elle seçtiği şehirle canlı konumu ilk bakışta ayırt etsin.
  final bool isGpsLocation;

  /// Vakit takvimi kısayolu; null ise düğme çizilmez.
  final VoidCallback? onCalendarTap;

  const HomeTopBar({
    super.key,
    required this.locationName,
    required this.onLocationTap,
    required this.onSettingsTap,
    this.onKerahatTap,
    this.onCalendarTap,
    this.isRefreshing = false,
    this.isGpsLocation = false,
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
                      if (isGpsLocation) ...[
                        Icon(
                          Icons.my_location_rounded,
                          key: kHomeGpsIconKey,
                          size: 16,
                          color: tokens.accent,
                        ),
                        const SizedBox(width: 6),
                      ],
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onCalendarTap != null)
                    IconButton(
                      tooltip: context.l10n.navCalendar,
                      onPressed: onCalendarTap,
                      icon: const Icon(Icons.calendar_month_rounded),
                      iconSize: 22,
                      color: tokens.textSecondary,
                    ),
                  if (onKerahatTap != null)
                    IconButton(
                      tooltip: context.l10n.kerahatSheetTitle,
                      onPressed: onKerahatTap,
                      icon: const Icon(Icons.wb_twilight_rounded),
                      iconSize: 22,
                      color: tokens.textSecondary,
                    ),
                  IconButton(
                    tooltip: context.l10n.settingsTitle,
                    onPressed: onSettingsTap,
                    padding: EdgeInsets.zero,
                    alignment: AlignmentDirectional.centerEnd,
                    icon: const Icon(Icons.settings_rounded),
                    iconSize: 22,
                    color: tokens.textSecondary,
                  ),
                ],
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

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 20),
      child: Text.rich(
        TextSpan(
          style: AppTypography.dateLine.copyWith(color: tokens.textSecondary),
          children: [
            TextSpan(text: gregorian),
            TextSpan(
              text: '  ·  ',
              style: TextStyle(color: tokens.textTertiary),
            ),
            TextSpan(
              text: HijriFormatter.format(date, context.l10n),
              style: TextStyle(color: tokens.accent),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
