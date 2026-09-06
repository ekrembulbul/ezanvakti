import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../features/prayer_times/domain/kerahat_times.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../utils/time_format_context.dart';

enum _KerahatCardStatus { next, active, completed }

const String _kerahatSourceUrl =
    'https://kurul.diyanet.gov.tr/tr/fetva/mekruh-vakitler-hangileridir-hangi-vakitlerde-kaza-ve-hangi-vakitlerde-nafile-namaz-kilinmaz/0193c42d-52b7-7186-d5b4-f1d3c950ad73';

/// Günün yaklaşık kerahat durumunu gösterir ve ayrıntı panelini açar.
class KerahatCard extends StatelessWidget {
  final List<KerahatInterval> intervals;
  final DateTime now;

  const KerahatCard({super.key, required this.intervals, required this.now});

  @override
  Widget build(BuildContext context) {
    if (intervals.isEmpty) return const SizedBox.shrink();

    final active = _firstWhereOrNull(
      intervals,
      (interval) => interval.contains(now),
    );
    final next = active == null
        ? _firstWhereOrNull(
            intervals,
            (interval) => interval.start.isAfter(now),
          )
        : null;
    final status = active != null
        ? _KerahatCardStatus.active
        : next != null
        ? _KerahatCardStatus.next
        : _KerahatCardStatus.completed;
    final selected = active ?? next;
    final tokens = context.tokens;
    final isActive = status == _KerahatCardStatus.active;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetails(context),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive ? tokens.kerahatSurface : tokens.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? tokens.kerahatLine : tokens.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 22,
                color: isActive ? tokens.kerahatText : tokens.textTertiary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title(context.l10n, status),
                      style: AppTypography.upcomingRowTitle.copyWith(
                        color: isActive
                            ? tokens.kerahatText
                            : tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      selected == null
                          ? context.l10n.kerahatCompletedHint
                          : '${_kindName(context.l10n, selected.kind)} · '
                                '${_timeRange(context, selected)}',
                      style: AppTypography.hint.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                    if (selected != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _remaining(context, status, selected),
                        style: AppTypography.hint.copyWith(
                          color: isActive
                              ? tokens.kerahatText
                              : tokens.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: tokens.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _title(AppLocalizations l10n, _KerahatCardStatus status) =>
      switch (status) {
        _KerahatCardStatus.next => l10n.kerahatNextTitle,
        _KerahatCardStatus.active => l10n.kerahatActiveTitle,
        _KerahatCardStatus.completed => l10n.kerahatCompletedTitle,
      };

  String _remaining(
    BuildContext context,
    _KerahatCardStatus status,
    KerahatInterval interval,
  ) {
    final target = status == _KerahatCardStatus.active
        ? interval.end
        : interval.start;
    final duration = formatCompactDuration(
      target.difference(now),
      context.l10n,
    );
    return status == _KerahatCardStatus.active
        ? context.l10n.kerahatEndsIn(duration)
        : context.l10n.kerahatStartsIn(duration);
  }

  String _timeRange(BuildContext context, KerahatInterval interval) =>
      context.l10n.kerahatTimeRange(
        context.formatTime(interval.start),
        context.formatTime(interval.end),
      );

  Future<void> _showDetails(BuildContext context) {
    final tokens = context.tokens;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.surface,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.8,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  sheetContext.l10n.kerahatSheetTitle,
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
                  sheetContext.l10n.kerahatApproximation,
                  style: AppTypography.rowSubtitle.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  sheetContext.l10n.kerahatExceptions,
                  style: AppTypography.rowSubtitle.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  sheetContext.l10n.kerahatSourceName,
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
      child: Row(
        children: [
          Expanded(
            child: Text(
              _kindName(context.l10n, interval.kind),
              style: AppTypography.rowSubtitle.copyWith(
                color: tokens.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
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

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final value in values) {
    if (test(value)) return value;
  }
  return null;
}
