import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../features/sermons/domain/sermon.dart';
import '../../../l10n/l10n_extensions.dart';

/// Ana sayfada hutbe günü ve bir gün öncesinde görünen kart.
class SermonCard extends StatelessWidget {
  final SermonSummary sermon;

  /// Arayüz dilindeki başlık (Türkçede konu, diğer dillerde PDF adı).
  final String title;
  final VoidCallback onOpen;

  const SermonCard({
    super.key,
    required this.sermon,
    required this.title,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    return Material(
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 8, 14),
          child: Row(
            children: [
              Icon(
                sermon.kind == SermonKind.bayram
                    ? Icons.celebration_rounded
                    : Icons.menu_book_rounded,
                color: tokens.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sermon.kind == SermonKind.bayram
                          ? l10n.sermonEid
                          : l10n.sermonThisWeek,
                      style: AppTypography.hint.copyWith(
                        color: tokens.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: AppTypography.rowTitle.copyWith(
                        color: tokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onOpen, child: Text(l10n.sermonRead)),
            ],
          ),
        ),
      ),
    );
  }
}
