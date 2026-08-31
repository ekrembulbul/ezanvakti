import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n_extensions.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
    super.dispose();
  }

  void _submit(String? code) {
    if (_handled || code == null || code.isEmpty) return;
    _handled = true;
    if (mounted) Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.qrScannerTitle)),
      body: widget.codes != null
          ? const SizedBox.expand()
          : MobileScanner(
              onDetect: (capture) =>
                  _submit(capture.barcodes.firstOrNull?.rawValue),
            ),
    );
  }
}
