import 'package:flutter/material.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../common/section_label.dart';
import 'qr_scanner_screen.dart';

const Key kQrScanButtonKey = Key('qr_scan_button');

/// Metin alanının ve okutma düğmesinin yüksekliği.
///
/// Tek bir sabit: düğme kare olduğu için kenarı da bu. Yükseklik önce
/// `IntrinsicHeight` ile alandan türetiliyordu; `InputDecorator`'ın doğal
/// yüksekliği çizilen kutudan biraz büyük olduğu için düğme alandan uzun
/// görünüyordu. Ölçüyü ikisine birden vermek bunu ortadan kaldırıyor.
const double _kFieldHeight = 56;
const Key kQrPayloadFieldKey = Key('qr_payload_field');

/// Alarma kaydedilecek QR kodunu alır: okutarak ya da elle yazarak.
///
/// Elle yazma bilerek var — kod yıpranır, kaybolur ya da kullanıcı seyahatte
/// olur; tek yol okutmak olsaydı acil çıkış dışında çare kalmazdı.
class QrPayloadField extends StatelessWidget {
  final TextEditingController controller;

  /// Testlerde kamera açılmasın diye; verilirse okutma bunun sonucunu kullanır.
  final Future<String?> Function(BuildContext context)? scanOverride;

  /// Okutma başarıyla sonuçlanınca çağrılır (elle yazmada çağrılmaz);
  /// düzenleme ekranı kodu kütüphaneye kaydetmeyi buradan önerir.
  final ValueChanged<String>? onScanned;

  const QrPayloadField({
    super.key,
    required this.controller,
    this.scanOverride,
    this.onScanned,
  });

  Future<void> _scan(BuildContext context) async {
    final scanner = scanOverride ?? _openScanner;
    final code = await scanner(context);
    if (code == null) return;
    controller.text = code;
    onScanned?.call(code);
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
        // gorunuyordu.
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: _kFieldHeight,
                child: TextField(
                  key: kQrPayloadFieldKey,
                  controller: controller,
                  // `expands` olmadan alan kendi dogal yuksekligini aliyor ve
                  // cizilen kutu 56'lik yuvanin icinde ortalanip kaliyordu:
                  // dugme alandan uzun gorunuyordu.
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(color: tokens.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Kodu okut ya da yaz',
                    hintStyle: TextStyle(color: tokens.textTertiary),
                    filled: true,
                    fillColor: tokens.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: _kFieldHeight,
              height: _kFieldHeight,
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

Future<String?> _openScanner(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const QrScannerScreen(),
    ),
  );
}
