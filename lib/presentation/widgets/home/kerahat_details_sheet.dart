import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../features/prayer_times/domain/kerahat_times.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../utils/time_format_context.dart';

const String _kerahatSourceUrl =
    'https://kurul.diyanet.gov.tr/tr/fetva/mekruh-vakitler-hangileridir-hangi-vakitlerde-kaza-ve-hangi-vakitlerde-nafile-namaz-kilinmaz/0193c42d-52b7-7186-d5b4-f1d3c950ad73';

/// Günün hesaplanan kerahat aralıklarını ve açıklamasını açar.
Future<void> showKerahatDetails(
  BuildContext context, {
  required List<KerahatInterval> intervals,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.tokens.backgroundStops.last,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.8,
      child: KerahatDetailsSheet(intervals: intervals),
    ),
  );
}

class KerahatDetailsSheet extends StatelessWidget {
  final List<KerahatInterval> intervals;

  const KerahatDetailsSheet({super.key, required this.intervals});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.kerahatSheetTitle,
              style: AppTypography.screenTitle.copyWith(
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            for (final interval in intervals) ...[
              _IntervalRow(interval: interval),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            Text(
              context.l10n.kerahatApproximation,
              style: AppTypography.rowSubtitle.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.kerahatExceptions,
              style: AppTypography.rowSubtitle.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.kerahatSourceName,
              style: AppTypography.hint.copyWith(color: tokens.textPrimary),
            ),
            const SizedBox(height: 6),
            SelectableText(
              _kerahatSourceUrl,
              style: AppTypography.hint.copyWith(color: tokens.accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntervalRow extends StatelessWidget {
  final KerahatInterval interval;

  const _IntervalRow({required this.interval});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.secondarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          Text(
            _kindName(context.l10n, interval.kind),
            style: AppTypography.rowSubtitle.copyWith(
              color: tokens.textPrimary,
            ),
          ),
          Text(
            context.l10n.kerahatTimeRange(
              context.formatTime(interval.start),
              context.formatTime(interval.end),
            ),
            style: AppTypography.upcomingRemaining.copyWith(
              color: tokens.textValue,
            ),
          ),
        ],
      ),
    );
  }
}

String _kindName(AppLocalizations l10n, KerahatKind kind) => switch (kind) {
  KerahatKind.afterSunrise => l10n.kerahatAfterSunrise,
  KerahatKind.beforeDhuhr => l10n.kerahatBeforeDhuhr,
  KerahatKind.beforeMaghrib => l10n.kerahatBeforeMaghrib,
};
