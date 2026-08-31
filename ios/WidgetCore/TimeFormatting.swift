import Foundation

/// Kullanıcının saat biçimi tercihi. Dart tarafındaki
/// `TimeFormatPreference.storageValue` ile birebir aynı değerler.
enum TimeFormatPreference: String {
    case system
    case h24
    case h12

    /// Tanınmayan ya da eksik değer sistem tercihine düşer.
    static func from(_ raw: String?) -> TimeFormatPreference {
        guard let raw, let value = TimeFormatPreference(rawValue: raw) else {
            return .system
        }
        return value
    }
}

/// Widget'taki saatleri kullanıcının tercihine göre biçimlendirir.
///
/// Saf tutuluyor ki XCTest'te sınanabilsin: takvim ve yerel ayar dışarıdan
/// verilir, `Date.now` kullanılmaz.
enum TimeFormatting {
    static func clock(
        _ date: Date,
        preference: TimeFormatPreference,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        switch preference {
        case .h24:
            formatter.dateFormat = "HH:mm"
        case .h12:
            // Yerel ayara göre AM/PM eki; sabit "a" yerine şablon kullanmak
            // 12 saatlik biçimi olmayan yerel ayarlarda da makul çıktı verir.
            formatter.dateFormat = "h:mm a"
        case .system:
            formatter.timeStyle = .short
            formatter.dateStyle = .none
        }
        return formatter.string(from: date)
    }
}
