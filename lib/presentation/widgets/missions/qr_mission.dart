import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

const Key kQrScannerKey = Key('qr_scanner');
const Key kQrHintKey = Key('qr_hint');

/// QR görevi: alarma kayıtlı kod okutulunca [onCompleted] çağrılır.
///
/// Kamera akışı dışarıdan verilebiliyor ([onDetectOverride]) ki testler
/// donanım gerektirmesin.
class QrMission extends StatefulWidget {
  /// Eşleşmesi gereken kod. Boşsa görev tamamlanamaz; kullanıcı acil çıkışa
  /// yönlendirilir.
  final String expected;

  final VoidCallback onCompleted;

  /// Testler için: kamera yerine bu akış dinlenir.
  final Stream<String>? codes;

  const QrMission({
    super.key,
    required this.expected,
    required this.onCompleted,
    this.codes,
  });

  @override
  State<QrMission> createState() => _QrMissionState();
}

class _QrMissionState extends State<QrMission> {
  bool _mismatch = false;

  StreamSubscription<String>? _injected;

  /// Kod görüş alanında kaldığı sürece okuma her karede yeniden geliyor.
  /// Tamamlama iki kez çağrılırsa görev ekranının altındaki sayfa da yığından
  /// düşüyor; ekran duruyor ama dokunmalara cevap vermiyor.
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _injected = widget.codes?.listen(_onCode);
  }

  @override
  void dispose() {
    _injected?.cancel();
    super.dispose();
  }

  void _onCode(String code) {
    if (!mounted || _completed) return;
    if (code.trim() == widget.expected.trim()) {
      _completed = true;
      widget.onCompleted();
      return;
    }
    setState(() => _mismatch = true);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    if (widget.expected.trim().isEmpty) {
      return _message(
        tokens,
        'Bu alarma kayıtlı bir QR kod yok.',
        'Alarmı düzenleyip kod ekleyebilir ya da acil çıkışı kullanabilirsin.',
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(child: _viewfinder(tokens)),
        const SizedBox(height: 20),
        Text(
          _mismatch ? 'Farklı bir kod okundu' : 'Kaydettiğin kodu okut',
          key: kQrHintKey,
          textAlign: TextAlign.center,
          style: AppTypography.rowTitle.copyWith(
            color: _mismatch ? tokens.accent : tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _mismatch
              ? 'Alarmı kurarken kaydettiğin kodu bul ve onu okut.'
              : 'Kamerayı koda doğru tut.',
          textAlign: TextAlign.center,
          style: AppTypography.rowSubtitle.copyWith(
            color: tokens.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _viewfinder(AppTokens tokens) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: tokens.divider),
          borderRadius: BorderRadius.circular(20),
        ),
        // Testte kamera acilmasin diye yalnizca gercek kullanimda kurulur.
        child: widget.codes != null
            ? Container(key: kQrScannerKey, color: tokens.surface)
            : MobileScanner(
                key: kQrScannerKey,
                onDetect: (capture) {
                  final value = capture.barcodes.firstOrNull?.rawValue;
                  if (value != null) _onCode(value);
                },
              ),
      ),
    );
  }

  Widget _message(AppTokens tokens, String title, String description) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.qr_code_2_rounded, size: 64, color: tokens.textTertiary),
        const SizedBox(height: 20),
        Text(
          title,
          key: kQrHintKey,
          textAlign: TextAlign.center,
          style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          textAlign: TextAlign.center,
          style: AppTypography.rowSubtitle.copyWith(
            color: tokens.textSecondary,
          ),
        ),
      ],
    );
  }
}
