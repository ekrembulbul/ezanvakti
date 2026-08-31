import 'package:flutter/material.dart';
import '../../l10n/l10n_extensions.dart';
import 'package:flutter/services.dart';

import '../../core/di/service_locator.dart';
import '../../core/interfaces/local_storage.dart';
import '../../core/models/notification_setting.dart' show PrayerType;
import '../../core/models/prayer_log.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/section_label.dart';

const Key kTrackingGridKey = Key('tracking_grid');

/// Namaz takibi: son yedi günün ızgarası ve kaza sayaçları.
///
/// Oyunlaştırma (seri, rozet) bilinçli olarak yok: ibadeti puana çevirmek
/// ürünün tonuna uymuyor. Izgara yalnızca hatırlatıcı bir defter.
class PrayerTrackingScreen extends StatefulWidget {
  /// Testler için; verilmezse `ServiceLocator`dan alınır.
  final LocalStorage? storage;

  /// Testlerde sabitlenebilsin diye.
  final DateTime? today;

  const PrayerTrackingScreen({super.key, this.storage, this.today});

  @override
  State<PrayerTrackingScreen> createState() => _PrayerTrackingScreenState();
}

class _PrayerTrackingScreenState extends State<PrayerTrackingScreen> {
  static const int _dayCount = 7;

  Map<String, PrayerStatus> _log = {};
  Map<PrayerType, int> _qada = {};
  bool _loading = true;

  LocalStorage get _storage =>
      widget.storage ?? ServiceLocator().get<LocalStorage>();

  DateTime get _today {
    final now = widget.today ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  List<DateTime> get _days => [
    for (var i = _dayCount - 1; i >= 0; i--)
      DateTime(_today.year, _today.month, _today.day - i),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final days = _days;
    final log = await _storage.getPrayerLog(days.first, days.last);
    final qada = await _storage.getQadaCounts();
    if (!mounted) return;
    setState(() {
      _log = log;
      _qada = qada;
      _loading = false;
    });
  }

  Future<void> _cycle(DateTime day, PrayerType type) async {
    final key = prayerLogKey(day, type);
    final next = nextPrayerStatus(_log[key]);
    setState(() {
      if (next == null) {
        _log.remove(key);
      } else {
        _log[key] = next;
      }
    });
    HapticFeedback.selectionClick();
    await _storage.setPrayerLog(day, type, next);
  }

  Future<void> _bumpQada(PrayerType type, int delta) async {
    final next = clampQadaCount((_qada[type] ?? 0) + delta);
    setState(() => _qada[type] = next);
    await _storage.setQadaCount(type, next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(title: context.l10n.trackingTitle),
      body: AppSurface(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  SectionLabel(context.l10n.trackingLastDays),
                  const SizedBox(height: 10),
                  _grid(),
                  const SizedBox(height: 12),
                  _legend(),
                  const SizedBox(height: 26),
                  SectionLabel(context.l10n.trackingQadaCounter),
                  const SizedBox(height: 10),
                  for (final type in trackedPrayerTypes) _qadaRow(type),
                ],
              ),
      ),
    );
  }

  Widget _grid() {
    final tokens = context.tokens;
    final days = _days;

    return Container(
      key: kTrackingGridKey,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 56),
              for (final day in days)
                Expanded(
                  child: Text(
                    '${day.day}',
                    textAlign: TextAlign.center,
                    style: AppTypography.hint.copyWith(
                      color: tokens.textTertiary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (final type in trackedPrayerTypes) _gridRow(type, days),
        ],
      ),
    );
  }

  Widget _gridRow(PrayerType type, List<DateTime> days) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              context.l10n.prayerName(type),
              style: AppTypography.hint.copyWith(color: tokens.textSecondary),
            ),
          ),
          for (final day in days)
            Expanded(
              child: GestureDetector(
                onTap: () => _cycle(day, type),
                child: Container(
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _cellColor(_log[prayerLogKey(day, type)]),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.border),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _cellColor(PrayerStatus? status) {
    final tokens = context.tokens;
    return switch (status) {
      PrayerStatus.done => tokens.accent,
      PrayerStatus.qada => tokens.accent.withValues(alpha: 0.35),
      PrayerStatus.missed => tokens.border,
      null => Colors.transparent,
    };
  }

  Widget _legend() {
    final tokens = context.tokens;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(context.l10n.trackingDone, tokens.accent),
        const SizedBox(width: 16),
        _legendItem(
          context.l10n.trackingQada,
          tokens.accent.withValues(alpha: 0.35),
        ),
        const SizedBox(width: 16),
        _legendItem(context.l10n.trackingEmpty, Colors.transparent),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    final tokens = context.tokens;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: tokens.border),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.hint.copyWith(color: tokens.textTertiary),
        ),
      ],
    );
  }

  Widget _qadaRow(PrayerType type) {
    final tokens = context.tokens;
    final count = _qada[type] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.prayerName(type),
              style: AppTypography.rowTitle.copyWith(
                color: tokens.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: count > 0 ? () => _bumpQada(type, -1) : null,
            icon: const Icon(Icons.remove_rounded, size: 20),
            color: tokens.accent,
            disabledColor: tokens.textTertiary,
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 56,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: AppTypography.rowTitle.copyWith(
                color: count == 0 ? tokens.textTertiary : tokens.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            onPressed: () => _bumpQada(type, 1),
            icon: const Icon(Icons.add_rounded, size: 20),
            color: tokens.accent,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
