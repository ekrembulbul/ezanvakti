import Foundation

/// Widget'taki kerahat çipinin metni.
///
/// Saf tutuluyor ki XCTest'te sınansın; görünüm (`KerahatChip`) yalnız bunu
/// çizer. Canlı dakika yok: widget dakikada bir yenilenemez, timeline kareleri
/// yaklaşma, başlangıç ve bitiş anlarında zaten değişiyor. Başlangıç saati
/// Türkçe bulunma eki almaz ("Kerahat 18:38"): eki burada üretmek ya da
/// snapshot'la taşımak kazandırdığı iki karaktere değmez.
enum KerahatChipLabel {
    /// - Parameter compact: küçük widget; kerahatte yalnız "Kerahat vakti"
    ///   yazar, orta boyda bitiş saati de sığar.
    static func text(
        status: KerahatStatus,
        compact: Bool,
        labels: SnapshotLabels?,
        timeFormat: TimeFormatPreference,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let kerahat = labels?.kerahat ?? "Kerahat"
        func clock(_ date: Date) -> String {
            TimeFormatting.clock(date, preference: timeFormat, locale: locale, timeZone: timeZone)
        }
        switch status {
        case let .approaching(start, _):
            return "\(kerahat) \(clock(start))"
        case let .active(end):
            if compact { return labels?.kerahatActive ?? "Kerahat vakti" }
            let until = (labels?.kerahatUntil ?? "bitiş {time}")
                .replacingOccurrences(of: "{time}", with: clock(end))
            return "\(kerahat) · \(until)"
        }
    }
}
