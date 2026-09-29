import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// Düzenleme ekranlarının altındaki silme düğmesi (spec 2026-09-28 §3.3).
///
/// Hata renginde, ortalı yazı ve çöp kutusu ikonu; en az 52 pt. Büyük metinde
/// yükseklik büyür, kırpılmaz. Onay sormaz ve kendisi pop yapmaz: çağıran
/// ekran önce kendini kapatır, sonra siler; "Geri al" çubuğu listede çıkar.
class DeleteActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  /// Formlarda ayrı bir yüzey kartında durur; konum ekranında "Kaydet"in
  /// altında kartsız çizilir.
  final bool framed;

  const DeleteActionButton(
    this.label,
    this.onPressed, {
    super.key,
    this.framed = true,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final error = Theme.of(context).colorScheme.error;
    final button = TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.delete_outline_rounded, size: 20),
      label: Text(label, textAlign: TextAlign.center),
      style: TextButton.styleFrom(
        foregroundColor: error,
        iconColor: error,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: AppTypography.rowTitle,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
    if (!framed) return button;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: button,
    );
  }
}
