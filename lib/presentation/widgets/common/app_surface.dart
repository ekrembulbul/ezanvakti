import 'package:flutter/material.dart';

import '../../../core/theme/tokens_context.dart';
import 'content_width.dart';

/// Ekranların ortak zemini: paletin radial gradyanı + güvenli alan.
///
/// Gradyan geometrisi paletten gelir; ekranlar kendi gradyanını tanımlamaz.
/// Zemin ekranı doldurur, içerik geniş ekranda [ContentWidth] ile ortalanır.
class AppSurface extends StatelessWidget {
  final Widget child;
  final bool safeAreaTop;
  final bool safeAreaBottom;

  /// Sekme kabuğu kapatır: sekmeler kendi [AppSurface]'iyle tam genişlikte
  /// çizilir, aksi halde iç gradyan dar sütunda dış gradyandan ayrışır.
  final bool limitContentWidth;

  const AppSurface({
    super.key,
    required this.child,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
    this.limitContentWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(gradient: context.tokens.backgroundGradient),
      child: SafeArea(
        top: safeAreaTop,
        bottom: safeAreaBottom,
        child: limitContentWidth ? ContentWidth(child: child) : child,
      ),
    );
  }
}
