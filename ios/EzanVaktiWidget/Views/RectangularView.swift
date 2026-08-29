import SwiftUI
import WidgetKit

/// Kilit ekranı ailelerinde sistem tek renge indirger; gradyan denenmez.
struct RectangularView: View {
    let entry: PrayerEntry

    var body: some View {
        switch entry.content {
        case .noData:
            Text("Vakitler için uygulamayı aç").font(.system(size: 12))
        case .needsUpdate:
            Text("Uygulamayı güncelleyin").font(.system(size: 12))
        case let .ready(next, _, _, _, isStale, _):
            VStack(alignment: .leading, spacing: 1) {
                Text(isStale ? "GÜNCEL DEĞİL" : "SIRADAKİ")
                    .font(.system(size: 10, weight: .semibold))
                    .widgetAccentable()

                HStack(spacing: 4) {
                    Text(next.name)
                    Text(next.date, format: .dateTime.hour().minute())
                        .monospacedDigit()
                }
                .font(.system(size: 15, weight: .semibold))

                Text(next.date, style: .timer)
                    .font(.system(size: 13).monospacedDigit())
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
