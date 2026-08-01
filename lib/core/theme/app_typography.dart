import 'package:flutter/material.dart';

/// Uygulamanın font ölçeği ve adlandırılmış metin stilleri.
///
/// Tasarım markup'ında 21 ad-hoc boyut vardı (yarım pikseller dahil); hepsi
/// aşağıdaki 10 basamağa normalize edildi. Ekranlarda çıplak `fontSize`
/// yazılmaz, bu sabitler kullanılır.
///
/// Stiller **renk taşımaz** — renk `AppTokens`'tan gelir. Böylece aynı stil
/// dört palette de yeniden kullanılabilir.
class AppTypography {
  const AppTypography._();

  static const String fontFamily = 'Manrope';

  /// İzin verilen tek font boyutu kümesi.
  ///
  /// `Set` değil `List`: `double` primitive equality taşımadığı için
  /// `const Set<double>` Dart'ta geçersizdir.
  static const List<double> scale = [11, 12, 13, 14, 16, 17, 20, 24, 44, 62];

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Ana ekrandaki geri sayım.
  static const TextStyle counter = TextStyle(
    fontFamily: fontFamily,
    fontSize: 62,
    fontWeight: FontWeight.w800,
    letterSpacing: -2.79,
    height: 1,
    fontFeatures: _tabular,
  );

  /// App bar başlığı.
  static const TextStyle screenTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w800,
  );

  /// Liste satırı başlığı ve konum başlığı.
  static const TextStyle rowTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.24,
  );

  /// Liste satırı alt metni.
  static const TextStyle rowSubtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  /// Ana ekrandaki vakit ızgarasının saat değeri.
  static const TextStyle gridValue = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.43,
    fontFeatures: _tabular,
  );

  /// "Yarın" şeridindeki saat değeri.
  static const TextStyle tomorrowValue = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
  );

  /// Sayacın üstündeki "SONRAKİ · AKŞAM" etiketi.
  static const TextStyle counterLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.4,
  );

  /// "3 ALARM", "SESSİZ SAATLER" gibi bölüm etiketleri.
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.76,
  );

  /// Izgaradaki "İMSAK", "GÜNEŞ" vakit adları.
  static const TextStyle gridPrayerName = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.66,
  );

  /// Gün cetvelindeki saatler.
  static const TextStyle rulerTime = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    fontFeatures: _tabular,
  );

  /// Kayan segment etiketi.
  static const TextStyle tabLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.14,
  );

  /// Miladi/hicri tarih satırı.
  static const TextStyle dateLine = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  /// Yardım ve alt bilgi metinleri.
  static const TextStyle hint = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  /// Tanımlı tüm stiller. Ölçek denetimi bu liste üzerinden yapılır; yeni bir
  /// stil eklenince buraya da eklenmeli.
  static const List<TextStyle> all = [
    counter,
    screenTitle,
    rowTitle,
    rowSubtitle,
    gridValue,
    tomorrowValue,
    counterLabel,
    sectionLabel,
    gridPrayerName,
    rulerTime,
    tabLabel,
    dateLine,
    hint,
  ];
}
