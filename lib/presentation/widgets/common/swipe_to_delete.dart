import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// Satırı sola kaydırarak silme.
///
/// Onay diyaloğu ve kaydırma arka planı tek yerde tanımlıdır; alarm ve
/// bildirim listeleri aynı davranışı paylaşır.
class SwipeToDelete extends StatelessWidget {
  final Key itemKey;
  final Widget child;
  final String confirmText;
  final VoidCallback onDelete;

  const SwipeToDelete({
    super.key,
    required this.itemKey,
    required this.child,
    required this.confirmText,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final errorColor = Theme.of(context).colorScheme.error;

    return Dismissible(
      key: itemKey,
      direction: DismissDirection.endToStart,
      background: Container(
        color: errorColor.withValues(alpha: 0.2),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline_rounded, color: errorColor),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: tokens.backgroundStops[1],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Sil',
              style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
            ),
            content: Text(
              confirmText,
              style: AppTypography.rowSubtitle.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: errorColor),
                child: const Text('Sil'),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      },
      onDismissed: (_) => onDelete(),
      child: child,
    );
  }
}
