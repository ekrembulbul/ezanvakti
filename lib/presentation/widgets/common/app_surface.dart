import 'package:flutter/material.dart';

import '../../../core/theme/tokens_context.dart';

/// Ekranların ortak zemini: paletin radial gradyanı + güvenli alan.
///
/// Gradyan geometrisi paletten gelir; ekranlar kendi gradyanını tanımlamaz.
class AppSurface extends StatelessWidget {
  final Widget child;
  final bool safeAreaTop;
  final bool safeAreaBottom;

  const AppSurface({
    super.key,
    required this.child,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(gradient: context.tokens.backgroundGradient),
      child: SafeArea(top: safeAreaTop, bottom: safeAreaBottom, child: child),
    );
  }
}
