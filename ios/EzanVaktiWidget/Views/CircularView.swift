import SwiftUI
import WidgetKit

/// Kilit ekranı halkası: vakte kalan oran + vaktin kısaltması.
///
/// Halkayı ve sayacı sistem çiziyor (`timerInterval`): widget'ın kendi
/// kareleri dakikada bir yenilenemez, Always-On ekranda ise hiç yenilenmez.
struct CircularView: View {
    let entry: PrayerEntry

    var body: some View {
        switch entry.content {
        case let .ready(next, _, _, _, _, _):
            // Halkayı ve süreyi sistem çiziyor: `ProgressView(timerInterval:)`
            // Always-On ekranda da canlı kalır, widget kendi karesini
            // yenilemek zorunda değildir.
            ProgressView(
                timerInterval: entry.date...next.date,
                countsDown: true,
                label: { Text(Self.abbreviation(next.name)) },
                currentValueLabel: {
                    Text(TimeFormatting.clock(next.date, preference: entry.timeFormat))
                        .font(.system(size: 11, weight: .semibold))
                }
            )
            .progressViewStyle(.circular)
        case .noData, .needsUpdate:
            ProgressView(value: 0) {
                Text("—")
            }
            .progressViewStyle(.circular)
        }
    }

    /// Halkada tam ad sığmıyor; ilk üç harf yeterli ayrım veriyor
    /// (İmsak/İkindi ilk harflerinde ayrışıyor).
    static func abbreviation(_ name: String) -> String {
        String(name.prefix(3))
    }
}
