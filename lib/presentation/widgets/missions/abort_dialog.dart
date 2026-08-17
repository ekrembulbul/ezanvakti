import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../features/alarms/domain/abort_gate.dart';

const Key kAbortHoldKey = Key('abort_hold');
const Duration kAbortHoldDuration = Duration(seconds: 3);

/// Acil çıkış akışı. Kademeye göre basılı tutma, cümle yazma ve geri sayım
/// ister. Çıkış her zaman mümkündür — yalnızca zorlaşır.
class AbortDialog extends StatefulWidget {
  final int level;
  final VoidCallback onConfirmed;

  const AbortDialog({
    super.key,
    required this.level,
    required this.onConfirmed,
  });

  @override
  State<AbortDialog> createState() => _AbortDialogState();
}

class _AbortDialogState extends State<AbortDialog> {
  late final AbortRequirement _req;
  final _controller = TextEditingController();
  Timer? _holdTimer;
  Timer? _countdownTimer;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _req = AbortGate.requirementFor(widget.level);
    _remaining = _req.countdownSeconds;
    if (_remaining > 0) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _remaining--);
        if (_remaining <= 0) t.cancel();
      });
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _countdownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool get _phraseOk =>
      !_req.requiresPhrase ||
      AbortGate.phraseMatches(expected: _req.phrase, typed: _controller.text);

  bool get _countdownOk => _remaining <= 0;

  void _holdStart() {
    _holdTimer = Timer(kAbortHoldDuration, () {
      if (_phraseOk && _countdownOk) widget.onConfirmed();
    });
  }

  void _holdEnd() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final atCeiling = AbortGate.isAtCeiling(widget.level);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Alarmı görevi yapmadan kapatıyorsun.',
            style: AppTypography.tabLabel.copyWith(color: tokens.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            atCeiling
                ? 'Çıkış artık en zor kademede; daha da zorlaşmayacak.'
                : 'Bir dahaki sefere çıkış daha zor olacak.',
            style: AppTypography.tabLabel.copyWith(color: tokens.textSecondary),
          ),
          if (_req.requiresPhrase) ...[
            const SizedBox(height: 16),
            Text(
              'Şunu birebir yaz: “${_req.phrase}”',
              style: AppTypography.tabLabel.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              // Kopyala-yapistir kapali: cumleyi gercekten yazmasi gerekiyor.
              enableInteractiveSelection: false,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'Cümleyi yaz'),
            ),
          ],
          if (_remaining > 0) ...[
            const SizedBox(height: 16),
            Text(
              'Bekle: $_remaining sn',
              style: AppTypography.tabLabel.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 24),
          GestureDetector(
            key: kAbortHoldKey,
            onLongPressDown: (_) => _holdStart(),
            onLongPressUp: _holdEnd,
            onLongPressCancel: _holdEnd,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.backgroundStops.first,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Kapatmak için 3 saniye basılı tut',
                style: AppTypography.tabLabel.copyWith(
                  color: tokens.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Acil çıkışı bir alt sayfada gösterir. Kullanıcı tamamlarsa `true` döner.
Future<bool> showAbortDialog({
  required BuildContext context,
  required int level,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: true,
    builder: (context) => AbortDialog(
      level: level,
      onConfirmed: () => Navigator.of(context).pop(true),
    ),
  );
  return result ?? false;
}
