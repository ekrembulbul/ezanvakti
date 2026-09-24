import 'package:flutter/material.dart';

/// Uygulamanın font ölçeği ve adlandırılmış metin stilleri.
///
/// Tasarım markup'ında 22 ad-hoc boyut vardı (yarım pikseller dahil); hepsi
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

  /// Degisken fontta agirlik `wght` ekseninden secilir; yalnizca [FontWeight]
  /// vermek sentetik kalinlik uretir, gercek eksen degerini kullanmaz.
  static const List<FontVariation> _w500 = [FontVariation('wght', 500)];
  static const List<FontVariation> _w600 = [FontVariation('wght', 600)];
  static const List<FontVariation> _w700 = [FontVariation('wght', 700)];
  static const List<FontVariation> _w800 = [FontVariation('wght', 800)];

  /// Ana ekrandaki geri sayım.
  static const TextStyle counter = TextStyle(
    fontFamily: fontFamily,
    fontSize: 62,
    fontWeight: FontWeight.w800,
    fontVariations: _w800,
    letterSpacing: -2.79,
    height: 1,
    fontFeatures: _tabular,
  );

  /// App bar başlığı.
  static const TextStyle screenTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    fontVariations: _w800,
  );

  /// Liste satırı başlığı ve konum başlığı.
  static const TextStyle rowTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    fontVariations: _w700,
    letterSpacing: -0.24,
  );

  /// Liste satırı alt metni.
  static const TextStyle rowSubtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    fontVariations: _w500,
  );

  /// Ana ekrandaki vakit ızgarasının saat değeri.
  static const TextStyle gridValue = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    fontVariations: _w700,
    letterSpacing: -0.43,
    fontFeatures: _tabular,
  );

  /// Hatırlatıcı listesindeki ana zaman veya vakit kuralı.
  static const TextStyle reminderPrimary = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    fontVariations: _w700,
    letterSpacing: -0.3,
    fontFeatures: _tabular,
  );

  /// "Yarın" şeridindeki saat değeri.
  static const TextStyle tomorrowValue = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    fontVariations: _w700,
    fontFeatures: _tabular,
  );

  /// Büyük harfli, geniş aralıklı başlık etiketi (konum ekleme başlığı).
  static const TextStyle counterLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    fontVariations: _w800,
    letterSpacing: 2.4,
  );

  /// "3 ALARM", "SESSİZ SAATLER" gibi bölüm etiketleri.
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    fontVariations: _w800,
    letterSpacing: 1.76,
  );

  /// Izgaradaki "İMSAK", "GÜNEŞ" vakit adları.
  static const TextStyle gridPrayerName = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    fontVariations: _w800,
    letterSpacing: 0.66,
  );

  /// Gün cetvelindeki saatler.
  static const TextStyle rulerTime = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    fontVariations: _w800,
    fontFeatures: _tabular,
  );

  /// Kayan segment etiketi.
  static const TextStyle tabLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    fontVariations: _w700,
    letterSpacing: -0.14,
  );

  /// Miladi/hicri tarih satırı.
  static const TextStyle dateLine = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    fontVariations: _w600,
  );

  /// "SIRADAKİ" kartındaki satır başlığı (markup 14.5 → ölçekte 14).
  static const TextStyle upcomingRowTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    fontVariations: _w700,
    letterSpacing: -0.14,
  );

  /// "SIRADAKİ" kartında sağdaki kalan süre (markup 13 w700).
  static const TextStyle upcomingRemaining = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    fontVariations: _w700,
    fontFeatures: _tabular,
  );

  /// Sayacın üstündeki "SONRAKİ  AKŞAM · 19:23" satırının etiketleri; saatten
  /// bir tık küçük (13 az kalıyordu, 2026-09-21).
  static const TextStyle heroLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    fontVariations: _w800,
    letterSpacing: 2.8,
  );

  /// Aynı satırdaki vakit saati; etiketten bir basamak büyük, sık aralıklı.
  static const TextStyle heroTime = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    fontVariations: _w800,
    letterSpacing: 0.5,
    fontFeatures: _tabular,
  );

  /// Üst satırın ortak dikey iskeleti: satırdaki her parça bu strut'u alır,
  /// kutuları eşitlenir ve etiket saatin taban çizgisine oturur (widget'taki
  /// gibi). `Wrap` taban çizgisi hizalayamadığından etiket ortalanıp yukarıda
  /// duruyordu (2026-09-21).
  static const StrutStyle heroStrut = StrutStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    forceStrutHeight: true,
  );

  /// Kerahat bandındaki "Kerahat" kelimesi.
  static const TextStyle kerahatBandLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    fontVariations: _w600,
  );

  /// Kerahat bandındaki dk:sn sayacı; kelimeyle aynı punto.
  static const TextStyle kerahatBandValue = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    fontVariations: _w700,
    fontFeatures: _tabular,
  );

  /// Yardım ve alt bilgi metinleri.
  static const TextStyle hint = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontVariations: _w500,
  );

  /// Tanımlı tüm stiller. Ölçek denetimi bu liste üzerinden yapılır; yeni bir
  /// stil eklenince buraya da eklenmeli.
  static const List<TextStyle> all = [
    counter,
    screenTitle,
    rowTitle,
    rowSubtitle,
    gridValue,
    reminderPrimary,
    tomorrowValue,
    counterLabel,
    sectionLabel,
    gridPrayerName,
    rulerTime,
    tabLabel,
    dateLine,
    upcomingRowTitle,
    upcomingRemaining,
    heroLabel,
    heroTime,
    kerahatBandLabel,
    kerahatBandValue,
    hint,
  ];
}
