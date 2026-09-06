import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/data/ramadan_periods.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../features/ramadan/domain/imsakiye_repository.dart';
import '../../../features/ramadan/domain/ramadan_period.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../controllers/imsakiye_controller.dart';
import '../common/state_widgets.dart';
import 'imsakiye_share_table.dart';
import 'imsakiye_table.dart';

class ImsakiyeView extends StatelessWidget {
  static const double _minimumTableWidth = 280;

  final ImsakiyeController controller;
  const ImsakiyeView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      DropdownButton<RamadanPeriod>(
        key: const Key('imsakiye-period'),
        isExpanded: true,
        value: controller.period,
        hint: Text(context.l10n.imsakiyePeriod),
        items: [
          for (final period in ramadanPeriods)
            DropdownMenuItem(
              value: period,
              child: Text('${period.hijriYear} / ${period.start.year}'),
            ),
        ],
        onChanged: (period) {
          if (period != null) controller.selectPeriod(period);
        },
      ),
      Text(
        '${imsakiyeDateRange(context, controller.period)} · ${context.l10n.calendarDayCount(controller.period.dayCount)}',
        style: AppTypography.hint.copyWith(color: context.tokens.textSecondary),
      ),
      const SizedBox(height: 4),
      Text(
        context.l10n.imsakiyeSources,
        style: AppTypography.hint.copyWith(color: context.tokens.textSecondary),
      ),
      const SizedBox(height: 8),
      if (controller.isLoading) const LinearProgressIndicator(),
      if (controller.error != null && controller.days.isNotEmpty)
        Text(context.l10n.imsakiyeRefreshFailed),
      Expanded(child: _content(context)),
    ],
  );

  Widget _content(BuildContext context) {
    if (controller.days.isEmpty) {
      if (controller.isLoading) {
        return LoadingState(message: context.l10n.calendarLoading);
      }
      return ErrorState(
        message: controller.error is IncompleteImsakiyeException
            ? context.l10n.imsakiyeIncomplete
            : context.l10n.imsakiyeLoadFailed,
        onRetry: controller.refresh,
      );
    }
    final fontSize = AppTypography.rowSubtitle.fontSize!;
    final textScale =
        MediaQuery.textScalerOf(context).scale(fontSize) / fontSize;
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(
                // Keep all six columns visible at the normal text size;
                // larger accessibility text can use horizontal scrolling.
                _minimumTableWidth * textScale,
                constraints.maxWidth,
              ),
              child: ImsakiyeTable(days: controller.days, compact: true),
            ),
          ),
        ),
      ),
    );
  }
}
