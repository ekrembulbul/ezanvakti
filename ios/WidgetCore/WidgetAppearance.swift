import Foundation

/// Kullanıcının uygulamadaki tema seçimi; `system` cihazın görünümünü izler.
/// Ham değerler Dart'taki `AppThemeMode.name` ile aynı.
enum WidgetThemeMode: String {
    case dark, light, system
}

/// Uygulamanın Görünüm ayarlarının widget'a taşınan kopyası.
///
/// Dart tarafındaki karşılığı `lib/features/home_widget/domain/widget_appearance.dart`;
/// anahtar adları oradaki JSON ile birebir aynı. Çalar ekranın
/// `AlarmAppearance`'ı ile aynı üç alan: widget de uygulama gibi renklenir,
/// yalnızca cihazın görünümünü izlemez.
struct WidgetAppearance: Decodable, Equatable {
    let themeMode: WidgetThemeMode

    /// Açıkken palet gün içinde vakte göre ilerler.
    let timeBasedColor: Bool

    /// `timeBasedColor` kapalıyken kullanılan palet.
    let fixedPalette: DayPhase

    /// Payload yokken (uygulama hiç açılmamış ya da bu anahtarı yazmayan eski
    /// sürüm) uygulamanın kurulum varsayılanı: sistem teması, vakte göre renk.
    static let fallback = WidgetAppearance(
        themeMode: .system, timeBasedColor: true, fixedPalette: DayPhase.fallback
    )

    init(themeMode: WidgetThemeMode, timeBasedColor: Bool, fixedPalette: DayPhase) {
        self.themeMode = themeMode
        self.timeBasedColor = timeBasedColor
        self.fixedPalette = fixedPalette
    }

    private enum CodingKeys: String, CodingKey {
        case themeMode, timeBasedColor, fixedPalette
    }

    /// Tanınmayan ya da eksik tek bir alan yalnızca kendini varsayılana
    /// düşürür (Dart'taki `AppearanceSettings.fromMap` ile aynı); diğer
    /// alanlar korunur. İleride eklenecek bir tema modu sabit paleti silmesin.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        themeMode = (try? container.decodeIfPresent(String.self, forKey: .themeMode))
            .flatMap(WidgetThemeMode.init(rawValue:)) ?? Self.fallback.themeMode
        timeBasedColor = (try? container.decodeIfPresent(Bool.self, forKey: .timeBasedColor))
            ?? Self.fallback.timeBasedColor
        fixedPalette = (try? container.decodeIfPresent(String.self, forKey: .fixedPalette))
            .flatMap(DayPhase.init(rawValue:)) ?? Self.fallback.fixedPalette
    }

    /// Eksik ya da bozuk payload bütünüyle varsayılana düşer: görünüm tercihi
    /// yüzünden widget boş kalmamalı.
    static func decode(_ raw: String?) -> WidgetAppearance {
        guard
            let raw,
            let data = raw.data(using: .utf8),
            let appearance = try? JSONDecoder().decode(WidgetAppearance.self, from: data)
        else { return fallback }
        return appearance
    }

    /// "Vakte göre renk" açıkken hesaplanan dilim, kapalıyken sabit palet.
    func phase(timeBased phase: DayPhase) -> DayPhase {
        timeBasedColor ? phase : fixedPalette
    }

    /// Koyu/açık seçimi; `system` ise cihazın o anki görünümü.
    func isDark(systemIsDark: Bool) -> Bool {
        switch themeMode {
        case .dark: return true
        case .light: return false
        case .system: return systemIsDark
        }
    }
}
