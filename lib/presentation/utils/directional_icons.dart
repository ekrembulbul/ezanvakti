import 'package:flutter/material.dart';

/// Yön duyarlı ikonlar.
///
/// Material ikonları `Directionality` ile kendiliğinden dönmez; RTL'de
/// "ileri" oku sola bakmalı. Tek yerde çözülüyor ki her çağıran kendi
/// kontrolünü yazmasın.
extension DirectionalIcons on BuildContext {
  bool get _isRtl => Directionality.of(this) == TextDirection.rtl;

  /// Listede "detaya git" oku.
  IconData get forwardChevron =>
      _isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded;

  /// Uygulama çubuğundaki geri oku.
  IconData get backArrow => _isRtl
      ? Icons.arrow_forward_ios_rounded
      : Icons.arrow_back_ios_new_rounded;
}
