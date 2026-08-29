import Foundation

/// Gösterilen günün miladi etiketi: `"Cumartesi, 29 Ağustos"`.
///
/// Hicri tarih burada üretilmez — o payload'dan gelir. Locale `tr_TR` ile
/// zorlanır çünkü uygulama tamamen Türkçe; cihaz diline bırakmak widget'ı
/// uygulamadan farklı bir dilde konuşturur.
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

    private static let parser: DateFormatter = {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        return parser
    }()

    static func gregorian(_ day: SnapshotDay) -> String? {
        guard let date = parser.date(from: day.date) else { return nil }
        return formatter.string(from: date)
    }
}
