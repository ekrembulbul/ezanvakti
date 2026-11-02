import 'package:flutter/widgets.dart';

/// Geniş ekranda (tablet, yatay telefon) içeriği ortada, okunur genişlikte
/// tutar; dar ekranda hiçbir şey yapmaz.
///
/// Kenar boşluğuyla daraltır, böylece çocuk sıkı (tight) kısıtı korur:
/// `Expanded` ve tam yükseklik bekleyen düzenler telefondaki gibi çalışır.
class ContentWidth extends StatelessWidget {
  /// Alt gezinme çubuğuyla aynı sınır; telefon düzeni bu genişliğe göre
  /// tasarlandı.
  static const double max = 600;

  final Widget child;

  const ContentWidth({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final extra = constraints.maxWidth - max;
        if (!constraints.hasBoundedWidth || extra <= 0) return child;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: extra / 2),
          child: child,
        );
      },
    );
  }
}
