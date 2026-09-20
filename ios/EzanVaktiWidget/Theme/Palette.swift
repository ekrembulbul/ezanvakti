import SwiftUI

/// `lib/core/theme/palettes.dart` portu. Değerler oradan birebir alınmıştır;
/// palet değişirse iki taraf birlikte güncellenmelidir.
struct Palette {
    let accent: Color
    let textPrimary: Color
    let textSecondary: Color

    /// Kerahat satırı; `palettes.dart` kerahatText ile birebir.
    let kerahat: Color
    let backgroundStops: [Color]

    /// Kerahat renkleri ve çizgi palet bağımsızdır; yalnız açık/koyu ayrımı
    /// gerekir. Kurucunun sonuna düşer; koyu paletler yazmaz.
    var isDark = true

    /// `palettes.dart` kerahatLine / kerahatSurface ile birebir.
    var kerahatLine: Color { Color(hex: isDark ? 0xA14158 : 0x8D243B) }
    var kerahatSurface: Color { Color(hex: isDark ? 0x3C1F2A : 0xF9E9EC) }

    /// Kerahat yaklaşırken çip turuncu; `palettes.dart` kerahatSoon* ile birebir.
    var kerahatSoonLine: Color { Color(hex: isDark ? 0xE0832E : 0xC9681C) }
    var kerahatSoonSurface: Color { Color(hex: isDark ? 0x3B2412 : 0xFDEFE1) }
    var kerahatSoonText: Color { Color(hex: isDark ? 0xFFB45C : 0xA9540E) }

    /// Üst blok ile alt bloğu ayıran çizgi; açık zeminde daha soluk yeter.
    var divider: Color { textSecondary.opacity(isDark ? 0.4 : 0.3) }

    /// Kerahat sürerken zemin bordo tona kayar; tasarımdan örneklenen sabit
    /// duraklar, kerahat renkleri gibi palet bağımsız.
    private var kerahatBackgroundStops: [Color] {
        isDark
            ? [Color(hex: 0x4B1E30), Color(hex: 0x2A1421), Color(hex: 0x150C11)]
            : [Color(hex: 0xE9B9C6), Color(hex: 0xF3D8DF), Color(hex: 0xFAEEF0)]
    }

    func kerahatBackgroundGradient(in size: CGSize) -> RadialGradient {
        Self.gradient(stops: kerahatBackgroundStops, in: size)
    }

    /// Zemin gradyanı. Geometri her palette aynı, yalnızca renkler değişir.
    ///
    /// Flutter karşılığı: `RadialGradient(center: Alignment(0.40, -1.08),
    /// radius: 1.25, stops: [0, 0.44, 1])` (`app_tokens.dart:82-87`).
    /// Alignment → UnitPoint dönüşümü: x = (0.40 + 1) / 2 = 0.70,
    /// y = (-1.08 + 1) / 2 = -0.04. Yarıçap kısa kenarın 1.25 katı.
    func backgroundGradient(in size: CGSize) -> RadialGradient {
        Self.gradient(stops: backgroundStops, in: size)
    }

    private static func gradient(stops: [Color], in size: CGSize) -> RadialGradient {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: stops[0], location: 0.0),
                .init(color: stops[1], location: 0.44),
                .init(color: stops[2], location: 1.0),
            ]),
            center: UnitPoint(x: 0.70, y: -0.04),
            startRadius: 0,
            endRadius: min(size.width, size.height) * 1.25
        )
    }

    /// Uygulamanın görünüm ayarı + hesaplanan dilim + cihazın görünümü.
    ///
    /// Tema `system` değilse cihazın koyu/açık tercihi yok sayılır: uygulama
    /// koyuyken widget da koyu. "Vakte göre renk" kapalıysa dilim yerine
    /// kullanıcının sabit paleti çizilir.
    static func resolve(
        _ appearance: WidgetAppearance, phase: DayPhase, colorScheme: ColorScheme
    ) -> Palette {
        let effectivePhase = appearance.phase(timeBased: phase)
        return appearance.isDark(systemIsDark: colorScheme == .dark)
            ? dark(effectivePhase)
            : light(effectivePhase)
    }

    private static func dark(_ phase: DayPhase) -> Palette {
        switch phase {
        case .morning: // ÇİVİT — İmsak → Öğle
            return Palette(
                accent: Color(hex: 0x93C4E8),
                textPrimary: Color(hex: 0xE8F0F8),
                textSecondary: Color(hex: 0xA5BDD2),
                kerahat: Color(hex: 0xFF9292),
                backgroundStops: [Color(hex: 0x2C5279), Color(hex: 0x143049), Color(hex: 0x08141F)]
            )
        case .afternoon: // KURŞUNİ — Öğle → İkindi
            return Palette(
                accent: Color(hex: 0xD8E8EE),
                textPrimary: Color(hex: 0xF0F5F7),
                textSecondary: Color(hex: 0xAFC3CB),
                kerahat: Color(hex: 0xFF9292),
                backgroundStops: [Color(hex: 0x40525C), Color(hex: 0x202C33), Color(hex: 0x10171B)]
            )
        case .evening: // ERGUVAN — İkindi → Yatsı
            return Palette(
                accent: Color(hex: 0xE09FB8),
                textPrimary: Color(hex: 0xF3EEF4),
                textSecondary: Color(hex: 0xB5A8C1),
                kerahat: Color(hex: 0xFF9292),
                backgroundStops: [Color(hex: 0x4A2144), Color(hex: 0x241634), Color(hex: 0x120E1B)]
            )
        case .night: // SÜMBÜL — Yatsı → İmsak
            return Palette(
                accent: Color(hex: 0xCDA6E4),
                textPrimary: Color(hex: 0xF2ECF6),
                textSecondary: Color(hex: 0xB3A5C1),
                kerahat: Color(hex: 0xFF9292),
                backgroundStops: [Color(hex: 0x2A2038), Color(hex: 0x17111F), Color(hex: 0x0A080E)]
            )
        }
    }

    /// Açık temada duraklar uygulamanınkinden **koyudur**.
    ///
    /// Uygulamada gradyan koca bir ekrana yayılıyor ve yumuşak bir geçiş
    /// okunuyor; 2x2'lik bir kutuda aynı değerler düz beyaz karta dönüşüyordu.
    /// Renk ailesi (ton) korunur, yalnızca duraklar arası kontrast açılır.
    /// Metin renkleri değişmedi; ilk durak koyulaştığı için kontrast arttı.
    private static func light(_ phase: DayPhase) -> Palette {
        switch phase {
        case .morning: // NİLÜFER
            return Palette(
                accent: Color(hex: 0x265F8E),
                textPrimary: Color(hex: 0x0E1D2C),
                textSecondary: Color(hex: 0x43596D),
                kerahat: Color(hex: 0x8D243B),
                backgroundStops: [Color(hex: 0xB8D2ED), Color(hex: 0xDCE9F7), Color(hex: 0xF3F8FC)],
                isDark: false
            )
        case .afternoon: // SEDEF
            return Palette(
                accent: Color(hex: 0x2A5B68),
                textPrimary: Color(hex: 0x0F1C21),
                textSecondary: Color(hex: 0x435A62),
                kerahat: Color(hex: 0x8D243B),
                backgroundStops: [Color(hex: 0xC2D8DE), Color(hex: 0xE2ECF0), Color(hex: 0xF4F9FA)],
                isDark: false
            )
        case .evening: // GÜLKURUSU
            return Palette(
                accent: Color(hex: 0x983F62),
                textPrimary: Color(hex: 0x201A1E),
                textSecondary: Color(hex: 0x5A4A50),
                kerahat: Color(hex: 0x8D243B),
                backgroundStops: [Color(hex: 0xEFCBD6), Color(hex: 0xF7E7EB), Color(hex: 0xFCF5F6)],
                isDark: false
            )
        case .night: // LEYLAK
            return Palette(
                accent: Color(hex: 0x5E3A80),
                textPrimary: Color(hex: 0x1A1424),
                textSecondary: Color(hex: 0x4F4260),
                kerahat: Color(hex: 0x8D243B),
                backgroundStops: [Color(hex: 0xD6C8E4), Color(hex: 0xEBE4F1), Color(hex: 0xF8F5FA)],
                isDark: false
            )
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
