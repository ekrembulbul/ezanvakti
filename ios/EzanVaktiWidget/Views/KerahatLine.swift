import SwiftUI
import WidgetKit

/// Sayacın altındaki kerahat satırı.
///
/// Yaklaşırken "Kerahat · 28:13": kalan süreyi sistemin aralık sayacı çizer,
/// Always-On'da da akar. Aktifken "Kerahat vakti · bitiş 19:32". Küçük
/// widget'ta başlangıç saati yazılmaz; yer yok.
struct KerahatLine: View {
    let entry: PrayerEntry
    let status: KerahatStatus
    let color: Color
    var showsStartTime = false

    var body: some View {
        HStack(spacing: 4) {
            switch status {
            case let .approaching(start, _):
                Text(entry.labels?.kerahat ?? "Kerahat")
                if showsStartTime {
                    Text(TimeFormatting.clock(start, preference: entry.timeFormat))
                        .monospacedDigit()
                }
                Text("·")
                Text(timerInterval: min(entry.date, start)...start, countsDown: true)
                    .monospacedDigit()
            case let .active(end):
                Text(entry.labels?.kerahatActive ?? "Kerahat vakti")
                Text("·")
                Text(Self.until(end, entry: entry))
                    .monospacedDigit()
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    static func until(_ end: Date, entry: PrayerEntry) -> String {
        let template = entry.labels?.kerahatUntil ?? "bitiş {time}"
        return template.replacingOccurrences(
            of: "{time}", with: TimeFormatting.clock(end, preference: entry.timeFormat))
    }
}
