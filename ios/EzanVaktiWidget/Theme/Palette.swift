import SwiftUI

/// `lib/core/theme/palettes.dart` portu. Değerler oradan birebir alınmıştır;
/// palet değişirse iki taraf birlikte güncellenmelidir.
struct Palette {
    let accent: Color
    let textPrimary: Color
    let textSecondary: Color

    /// Kerahat satırı; `palettes.dart` kerahatText ile birebir.
    let kerahat: Color
    /// Zemin durakları hex olarak tutulur: kerahatte bordoya karıştırılabilsin
    /// (`duringKerahat(active:)`); `Color`'ın bileşenleri okunamıyor.
    let backgroundHex: [UInt32]

    /// Kerahat renkleri ve çizgi palet bağımsızdır; yalnız açık/koyu ayrımı
    /// gerekir. Kurucunun sonuna düşer; koyu paletler yazmaz.
    var isDark = true

    /// `palettes.dart` kerahatLine / kerahatSurface ile birebir.
    var kerahatLine: Color { Color(hex: isDark ? 0xA14158 : 0x8D243B) }
    var kerahatSurface: Color { Color(hex: isDark ? 0x3C1F2A : 0xF9E9EC) }

    /// Kerahat yaklaşırken turuncu; `palettes.dart` kerahatSoon* ile birebir.
    var kerahatSoonLine: Color { Color(hex: isDark ? 0xE0832E : 0xC9681C) }
    var kerahatSoonSurface: Color { Color(hex: isDark ? 0x3B2412 : 0xFDEFE1) }
    var kerahatSoonText: Color { Color(hex: isDark ? 0xFFB45C : 0xA9540E) }

    /// Yaklaşırken kartın/bandın dolgusu (2026-10-09): `kerahatSoonSurface`
    /// açık zeminde seçilmiyordu, bu ton daha doygun.
    var kerahatSoonFill: Color { Color(hex: isDark ? 0x4A2D14 : 0xFADFC2) }

    /// Kerahat sürerken zemin duraklarının vardığı bordo; durak durak
    /// `backgroundHex` ile eşleşir.
    var kerahatWine: [UInt32] {
        isDark ? [0x6A2238, 0x35151F, 0x150B10] : [0xE8B3C0, 0xF3D7DE, 0xFBEFF2]
    }

    /// Kerahatte zeminin bordoya kayma oranı (Android ile aynı).
    static let kerahatWineAmount = 0.88

    var backgroundStops: [Color] { backgroundHex.map { Color(hex: $0) } }

    /// Kerahat sürerken (yalnız `.active`; yaklaşırken değil) her zemin durağı
    /// karşılık gelen `kerahatWine` durağına %88 karışır; geometri aynı kalır.
    /// Zemini okuyan her parça (gradyan, cetvel noktasının halkası) bu
    /// paletten çizilsin ki tutarlı olsun.
    func duringKerahat(active: Bool) -> Palette {
        guard active else { return self }
        let wine = kerahatWine
        return Palette(
            accent: accent,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            kerahat: kerahat,
            backgroundHex: zip(backgroundHex, wine).map {
                Self.mix($0, $1, Self.kerahatWineAmount)
            },
            isDark: isDark
        )
    }

    /// İki sRGB rengi bileşen bileşen karıştırır: a + (b − a) × t, en yakın
    /// tamsayıya yuvarlanır. Saf; alfa yok sayılır.
    static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 {
            let from = Double((a >> shift) & 0xFF)
            let to = Double((b >> shift) & 0xFF)
            let value = (from + (to - from) * t).rounded()
            return UInt32(min(max(value, 0), 255)) << shift
        }
        return channel(16) | channel(8) | channel(0)
    }

    /// Üst blok ile alt bloğu ayıran çizgi; açık zeminde daha soluk yeter.
    var divider: Color { textSecondary.opacity(isDark ? 0.4 : 0.3) }

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
                backgroundHex: [0x2C5279, 0x143049, 0x08141F]
            )
        case .afternoon: // KURŞUNİ — Öğle → İkindi
            return Palette(
                accent: Color(hex: 0xD8E8EE),
                textPrimary: Color(hex: 0xF0F5F7),
                textSecondary: Color(hex: 0xAFC3CB),
                kerahat: Color(hex: 0xFF9292),
                backgroundHex: [0x40525C, 0x202C33, 0x10171B]
            )
        case .evening: // ERGUVAN — İkindi → Yatsı
            return Palette(
                accent: Color(hex: 0xE09FB8),
                textPrimary: Color(hex: 0xF3EEF4),
                textSecondary: Color(hex: 0xB5A8C1),
                kerahat: Color(hex: 0xFF9292),
                backgroundHex: [0x4A2144, 0x241634, 0x120E1B]
            )
        case .night: // SÜMBÜL — Yatsı → İmsak
            return Palette(
                accent: Color(hex: 0xCDA6E4),
                textPrimary: Color(hex: 0xF2ECF6),
                textSecondary: Color(hex: 0xB3A5C1),
                kerahat: Color(hex: 0xFF9292),
                backgroundHex: [0x2A2038, 0x17111F, 0x0A080E]
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
                backgroundHex: [0xB8D2ED, 0xDCE9F7, 0xF3F8FC],
                isDark: false
            )
        case .afternoon: // SEDEF
            return Palette(
                accent: Color(hex: 0x2A5B68),
                textPrimary: Color(hex: 0x0F1C21),
                textSecondary: Color(hex: 0x435A62),
                kerahat: Color(hex: 0x8D243B),
                backgroundHex: [0xC2D8DE, 0xE2ECF0, 0xF4F9FA],
                isDark: false
            )
        case .evening: // GÜLKURUSU
            return Palette(
                accent: Color(hex: 0x983F62),
                textPrimary: Color(hex: 0x201A1E),
                textSecondary: Color(hex: 0x5A4A50),
                kerahat: Color(hex: 0x8D243B),
                backgroundHex: [0xEFCBD6, 0xF7E7EB, 0xFCF5F6],
                isDark: false
            )
        case .night: // LEYLAK
            return Palette(
                accent: Color(hex: 0x5E3A80),
                textPrimary: Color(hex: 0x1A1424),
                textSecondary: Color(hex: 0x4F4260),
                kerahat: Color(hex: 0x8D243B),
                backgroundHex: [0xD6C8E4, 0xEBE4F1, 0xF8F5FA],
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
