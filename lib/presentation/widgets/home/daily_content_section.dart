import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/app_logger.dart';
import '../../../features/daily_content/domain/daily_content.dart';
import '../../../l10n/l10n_extensions.dart';
import '../common/app_bar_widgets.dart';

/// Ana sayfadaki günün ayeti, hadisi ve duası kartları. Metinler Diyanet'ten
/// geldiği gibi gösterilir; her kart paylaşılabilir, basılı tutunca kopyalanır.
class DailyContentSection extends StatelessWidget {
  final DailyContent content;

  const DailyContentSection({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DailyCard(
          key: const ValueKey('daily-verse'),
          title: l10n.dailyVerseTitle,
          text: content.verse,
          source: content.verseSource,
        ),
        const SizedBox(height: 12),
        _DailyCard(
          key: const ValueKey('daily-hadith'),
          title: l10n.dailyHadithTitle,
          text: content.hadith,
          source: content.hadithSource,
        ),
        const SizedBox(height: 12),
        _DailyCard(
          key: const ValueKey('daily-prayer'),
          title: l10n.dailyPrayerTitle,
          text: content.prayer,
          source: content.prayerSource,
        ),
      ],
    );
  }
}

class _DailyCard extends StatelessWidget {
  final String title;
  final String text;
  final String? source;

  const _DailyCard({
    super.key,
    required this.title,
    required this.text,
    required this.source,
  });

  String get _withSource => source == null ? text : '$text\n$source';

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final copied = context.l10n.dailyContentCopied;
    await Clipboard.setData(ClipboardData(text: _withSource));
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(copied)));
  }

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: '$title\n\n$_withSource',
          sharePositionOrigin: origin,
        ),
      );
    } catch (error, stack) {
      AppLogger().warning('Daily content share failed', error, stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final source = this.source;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _copy(context),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 16),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.rowTitle.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
                AppBarActionButton(
                  icon: Icons.ios_share_rounded,
                  tooltip: context.l10n.actionShare,
                  onTap: () => _share(context),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Text(
                text,
                style: AppTypography.hint.copyWith(
                  fontSize: 16,
                  height: 1.5,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            if (source != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Text(
                  source,
                  textAlign: TextAlign.end,
                  style: AppTypography.hint.copyWith(
                    color: tokens.textTertiary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
