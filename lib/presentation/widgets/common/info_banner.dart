import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// İzin uyarısı ve bilgilendirme bandı.
///
/// Spec §4.1: uyarı, seçim ve pasif durumlar **nötr kalır** — vurgu rengi
/// yalnızca vakit bilgisi ve tek birincil eylem içindir. Bu yüzden band
/// yüzey/kenarlık token'larını kullanır, accent'i değil.
class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const InfoBanner({
    super.key,
    required this.icon,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: tokens.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTypography.hint.copyWith(color: tokens.textSecondary),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
