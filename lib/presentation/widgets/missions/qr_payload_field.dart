import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../common/section_label.dart';

const Key kQrScanButtonKey = Key('qr_scan_button');
const Key kQrPayloadFieldKey = Key('qr_payload_field');

/// Alarma kaydedilecek QR kodunu alır: okutarak ya da elle yazarak.
///
/// Elle yazma bilerek var — kod yıpranır, kaybolur ya da kullanıcı seyahatte
/// olur; tek yol okutmak olsaydı acil çıkış dışında çare kalmazdı.
class QrPayloadField extends StatelessWidget {
  final TextEditingController controller;

  /// Testlerde kamera açılmasın diye; verilirse okutma bunun sonucunu kullanır.
  final Future<String?> Function(BuildContext context)? scanOverride;

  const QrPayloadField({
    super.key,
    required this.controller,
    this.scanOverride,
  });

  Future<void> _scan(BuildContext context) async {
    final scanner = scanOverride ?? _openScanner;
    final code = await scanner(context);
    if (code == null) return;
    controller.text = code;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('QR KOD'),
        const SizedBox(height: 8),
        // Okutma dugmesi alanin yaninda duruyor: ikisi de ayni isi — kodu
        // doldurmayi — yapiyor, alt alta durunca ikinci bir adim gibi
        // gorunuyordu. Yukseklik `IntrinsicHeight` ile alandan aliniyor,
        // sabit bir olcuye baglanmiyor.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: TextField(
                  key: kQrPayloadFieldKey,
                  controller: controller,
                  style: TextStyle(color: tokens.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Kodu okut ya da yaz',
                    hintStyle: TextStyle(color: tokens.textTertiary),
                    filled: true,
                    fillColor: tokens.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: tokens.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: tokens.divider),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AspectRatio(
                aspectRatio: 1,
                child: Tooltip(
                  // Ikon tek basina kaldigi icin eylemin adi burada yasiyor;
                  // ekran okuyucu da bunu okuyor.
                  message: 'Kodu okut',
                  child: OutlinedButton(
                    key: kQrScanButtonKey,
                    onPressed: () => _scan(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: tokens.accent,
                      side: BorderSide(color: tokens.accent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Kodu yatağından uzak bir yere yapıştır: banyo kapısı, mutfak. '
          'Alarm ancak bu kod okutulunca kapanır.',
          style: AppTypography.hint.copyWith(
            color: tokens.textTertiary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Tam ekran okuyucu; okunan ilk kodu döner.
Future<String?> _openScanner(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Kodu okut')),
        body: MobileScanner(
          onDetect: (capture) {
            final value = capture.barcodes.firstOrNull?.rawValue;
            if (value != null) Navigator.of(context).pop(value);
          },
        ),
      ),
    ),
  );
}
