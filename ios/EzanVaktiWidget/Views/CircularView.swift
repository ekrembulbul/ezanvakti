import SwiftUI
import WidgetKit

/// Kilit ekranı yuvarlağı: sıradaki vaktin kısaltması ve saati.
///
/// Halka yok: `ProgressView(timerInterval:)` da `Text(timerInterval:)` gibi
/// sistemin sayacına dayanıyor ve kilitli cihazda kalan süre yanlış
/// görünüyordu (2026-09-14 cihaz gözlemi). Kilit ekranı yalnız kare
/// değişmeden doğru kalan bilgiyi gösterir; kare her vakit geçişinde yenilenir.
struct CircularView: View {
    let entry: PrayerEntry

    var body: some View {
        switch entry.content {
        case let .ready(next, _, _, _, _, _):
            VStack(spacing: 0) {
                Text(Self.abbreviation(next.name))
                    .font(.system(size: 11, weight: .semibold))
                    .widgetAccentable()
                Text(TimeFormatting.clock(next.date, preference: entry.timeFormat))
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 4)
        case .noData, .needsUpdate:
            Text("—")
                .font(.system(size: 15, weight: .semibold))
        }
    }

    /// Yuvarlakta tam ad sığmıyor; ilk üç harf yeterli ayrım veriyor
    /// (İmsak/İkindi ilk harflerinde ayrışıyor).
    static func abbreviation(_ name: String) -> String {
        String(name.prefix(3))
    }
}
