import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/hijri_formatter.dart';

/// Ana ekranın üst çubuğu: uygulama ikonu · konum · menü.
class HomeTopBar extends StatelessWidget {
  final String locationName;
  final VoidCallback? onLocationTap;
  final VoidCallback onMenuTap;

  const HomeTopBar({
    super.key,
    required this.locationName,
    required this.onLocationTap,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 30,
              height: 30,
            ),
          ),
          const SizedBox(width: 12),
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
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onMenuTap,
            child: Icon(
              Icons.menu_rounded,
              size: 23,
              color: tokens.textSecondary,
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
    final gregorian = DateFormat('EEEE, d MMMM y', 'tr_TR').format(date);

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
            HijriFormatter.format(date),
            style: AppTypography.dateLine.copyWith(color: tokens.accent),
          ),
        ],
      ),
    );
  }
}
