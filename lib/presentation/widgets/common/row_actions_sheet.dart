import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../l10n/l10n_extensions.dart';
import 'section_label.dart';

/// Satıra basılı tutunca açılan eylem sayfası (spec 2026-09-28 §3.3).
///
/// [title] kaydı tanıtır; bölüm etiketi gibi Türkçe kurala göre büyük harfle
/// yazılır. "Kopyala" yalnız [onDuplicate] verilince görünür. "Sil" onay
/// sormaz: geri alma çağıranın "Geri al" çubuğuyla verilir (proje standardı).
/// Her eylemde önce sayfa kapanır, sonra geri çağırım çalışır; böylece çubuk
/// listenin üstünde çıkar.
Future<void> showRowActionsSheet(
  BuildContext context, {
  String? title,
  VoidCallback? onDuplicate,
  required VoidCallback onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final tokens = sheetContext.tokens;
      final l10n = sheetContext.l10n;
      final error = Theme.of(sheetContext).colorScheme.error;
      final heading = title?.trim();
      final duplicate = onDuplicate;

      void run(VoidCallback action) {
        Navigator.pop(sheetContext);
        action();
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (heading != null && heading.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 8),
                child: SectionLabel(heading),
              ),
            if (duplicate != null)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Icon(Icons.copy_rounded, color: tokens.textSecondary),
                title: Text(
                  l10n.alarmDuplicate,
                  style: AppTypography.rowTitle.copyWith(
                    color: tokens.textPrimary,
                  ),
                ),
                onTap: () => run(duplicate),
              ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Icon(Icons.delete_outline_rounded, color: error),
              title: Text(
                l10n.actionDelete,
                style: AppTypography.rowTitle.copyWith(color: error),
              ),
              onTap: () => run(onDelete),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
