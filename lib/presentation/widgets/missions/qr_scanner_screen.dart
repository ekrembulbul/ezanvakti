import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n_extensions.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'torch_button.dart';

/// Tam ekran QR okuyucu; okunan **ilk** kodu döndürür.
class QrScannerScreen extends StatefulWidget {
  /// Testlerde kamera açılmasın diye; verilirse okuma bunu dinler.
  final Stream<String>? codes;

  const QrScannerScreen({super.key, this.codes});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  StreamSubscription<String>? _injected;

  /// Testte kamera açılmasın diye yalnızca gerçek kullanımda kurulur; flaş
  /// düğmesi de bu denetleyiciye bağlı.
  late final MobileScannerController? _controller = widget.codes != null
      ? null
      : MobileScannerController();

  /// Kamera saniyede onlarca kare üretiyor ve kod görüş alanında kaldığı
  /// sürece okuma tekrar tekrar geliyor; okuyucu kapanırken akış hemen
  /// susmuyor. Her okuma `pop` çağırınca yalnızca okuyucu değil, altındaki
  /// alarm ekranı da yığından düşüyordu: ekran duruyor ama "Kaydet" ve geri
  /// düğmesi cevap vermiyordu.
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _injected = widget.codes?.listen(_submit);
  }

  @override
  void dispose() {
    _injected?.cancel();
    unawaited(_controller?.dispose());
    super.dispose();
  }

  void _submit(String? code) {
    if (_handled || code == null || code.isEmpty) return;
    _handled = true;
    if (mounted) Navigator.of(context).pop(code);
  }

  Widget? _torchAction() {
    final controller = _controller;
    if (controller == null) return null;
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (_, state, _) => TorchButton(
        state: state.torchState,
        onPressed: () => unawaited(controller.toggleTorch()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.qrScannerTitle),
        actions: [?_torchAction()],
      ),
      body: widget.codes != null
          ? const SizedBox.expand()
          : MobileScanner(
              controller: _controller,
              onDetect: (capture) =>
                  _submit(capture.barcodes.firstOrNull?.rawValue),
            ),
    );
  }
}
