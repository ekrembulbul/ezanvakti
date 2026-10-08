import Foundation

/// Gösterilen günün miladi etiketleri: `"Perşembe, 8 Ekim"`, `"8 Ekim"`,
/// `"Perşembe"`.
///
/// Metin önce payload'dan gelir (`weekday`, `dateLabel`, 2026-10-08):
/// uygulama onları kendi dilinde biçimler, uygulama İngilizce ya da Arapçayken
/// widget artık Türkçe konuşmaz. Eski uygulamanın payload'ında bu alanlar yok;
/// o zaman `tr_TR` ile biçimlenir (uygulamanın kaynak dili). Hicri tarih
/// burada üretilmez — o da payload'dan gelir.
enum DayLabel {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.calendar = Calendar(identifier: .gregorian)
        // setLocalizedDateFormatFromTemplate tr_TR icin "29 Agustos
        // Cumartesi" sirasini uretiyor; bicim sabitleniyor.
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter
    }()

    /// Kısa biçim: `"14 Eylül"` (küçük widget'ın üst satırı, konumun yanında).
    private static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "d MMMM"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    private static let parser: DateFormatter = {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        return parser
    }()

    /// `"Perşembe, 8 Ekim"`. Payload'da gün adı ve tarih birlikte varsa
    /// onlar; biri eksikse ikisi de `tr_TR` biçiminden (iki dil yan yana
    /// düşmesin).
    static func gregorian(_ day: SnapshotDay) -> String? {
        if let weekday = nonEmpty(day.weekday), let dateLabel = nonEmpty(day.dateLabel) {
            return "\(weekday), \(dateLabel)"
        }
        guard let date = parser.date(from: day.date) else { return nil }
        return formatter.string(from: date)
    }

    /// `"8 Ekim"`: gün adı yok.
    static func short(_ day: SnapshotDay) -> String? {
        if let dateLabel = nonEmpty(day.dateLabel) { return dateLabel }
        guard let date = parser.date(from: day.date) else { return nil }
        return shortFormatter.string(from: date)
    }

    /// `"Perşembe"`: küçük widget'ın alt yuvası.
    static func weekday(_ day: SnapshotDay) -> String? {
        if let weekday = nonEmpty(day.weekday) { return weekday }
        guard let date = parser.date(from: day.date) else { return nil }
        return weekdayFormatter.string(from: date)
    }

    /// Orta boyun sağ üstü: `"Perşembe, 8 Ekim · 27 Rebiülahir"`. Eksik parça
    /// atlanır; eski payload'da yılsız hicri yok, yalnız miladi kalır (yıllı
    /// hicri bu satıra sığmıyor).
    static func header(_ day: SnapshotDay) -> String? {
        let parts = [gregorian(day), nonEmpty(day.hijriShort)].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
