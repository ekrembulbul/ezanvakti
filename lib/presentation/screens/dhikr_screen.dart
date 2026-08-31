import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/di/service_locator.dart';
import '../../core/interfaces/local_storage.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../../features/tracking/domain/dhikr_counter.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/option_picker.dart';

const Key kDhikrTapAreaKey = Key('dhikr_tap_area');
const Key kDhikrCountKey = Key('dhikr_count');

/// Zikirmatik: hedefli sayaç.
///
/// Sayaç günlük saklanır — kullanıcı uygulamayı kapatıp açtığında o günkü
/// toplamı bulur; ertesi gün sıfırdan başlar.
class DhikrScreen extends StatefulWidget {
  final LocalStorage? storage;
  final DateTime? today;

  const DhikrScreen({super.key, this.storage, this.today});

  @override
  State<DhikrScreen> createState() => _DhikrScreenState();
}

class _DhikrScreenState extends State<DhikrScreen> {
  DhikrState _state = const DhikrState(count: 0, target: 33);
  bool _loading = true;

  LocalStorage get _storage =>
      widget.storage ?? ServiceLocator().get<LocalStorage>();

  DateTime get _today {
    final now = widget.today ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final count = await _storage.getDhikrCount(_today);
    if (!mounted) return;
    setState(() {
      _state = DhikrState(count: count, target: _state.target);
      _loading = false;
    });
  }

  Future<void> _tap() async {
    final next = _state.increment();
    setState(() => _state = next);
    // Tur tamamlandığında daha belirgin bir geri bildirim: kullanıcı ekrana
    // bakmadan sayabilsin.
    if (next.inLap == 0) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    await _storage.setDhikrCount(_today, next.count);
  }

  Future<void> _undo() async {
    final next = _state.decrement();
    setState(() => _state = next);
    await _storage.setDhikrCount(_today, next.count);
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sayacı sıfırla'),
        content: const Text('Bugünkü zikir sayısı silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final next = _state.reset();
    setState(() => _state = next);
    await _storage.setDhikrCount(_today, 0);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(
        title: 'Zikirmatik',
        actions: [
          IconButton(
            onPressed: _loading ? null : _undo,
            icon: const Icon(Icons.undo_rounded),
            color: tokens.textSecondary,
            tooltip: 'Geri al',
          ),
          IconButton(
            onPressed: _loading ? null : _reset,
            icon: const Icon(Icons.refresh_rounded),
            color: tokens.textSecondary,
            tooltip: 'Sıfırla',
          ),
        ],
      ),
      body: AppSurface(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: OptionRow<int>(
                      label: 'Hedef',
                      selected: _state.target,
                      valueLabel: (value) => '$value',
                      items: [
                        for (final target in kDhikrTargets)
                          OptionItem(value: target, label: '$target'),
                      ],
                      onChanged: (value) =>
                          setState(() => _state = _state.withTarget(value)),
                    ),
                  ),
                  Expanded(child: _tapArea()),
                ],
              ),
      ),
    );
  }

  /// Tüm alan dokunmaya duyarlı: kullanıcı ekrana bakmadan, parmağını
  /// herhangi bir yere koyup sayabilsin.
  Widget _tapArea() {
    final tokens = context.tokens;

    return GestureDetector(
      key: kDhikrTapAreaKey,
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              key: kDhikrCountKey,
              '${_state.inLap}',
              style: AppTypography.screenTitle.copyWith(
                color: tokens.textPrimary,
                fontSize: 88,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hedefe ${_state.remaining} · Tur ${_state.laps}',
              style: AppTypography.rowSubtitle.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Bugün toplam ${_state.count}',
              style: AppTypography.hint.copyWith(color: tokens.textTertiary),
            ),
            const SizedBox(height: 40),
            Text(
              'Saymak için ekrana dokun',
              style: AppTypography.hint.copyWith(color: tokens.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
