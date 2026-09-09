import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../l10n/l10n_extensions.dart';

/// QR okuyucudaki flaş düğmesi.
///
/// Karanlıkta kod okutmak flaşsız pratikte imkânsız; sabah alarmı zaten
/// karanlıkta çalıyor.
///
/// Flaşsız cihazda ([TorchState.unavailable]) hiç çizilmez: basılamayan bir
/// düğme göstermek, kullanıcıya olmayan bir çıkış vaat eder.
class TorchButton extends StatelessWidget {
  final TorchState state;
  final VoidCallback? onPressed;

  const TorchButton({super.key, required this.state, this.onPressed});

  bool get _isOn => state == TorchState.on;

  @override
  Widget build(BuildContext context) {
    if (state == TorchState.unavailable) return const SizedBox.shrink();
    final label = _isOn ? context.l10n.qrTorchOff : context.l10n.qrTorchOn;
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      icon: Icon(
        _isOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
        semanticLabel: label,
      ),
    );
  }
}
