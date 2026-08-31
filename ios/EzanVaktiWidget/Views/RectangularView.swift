import SwiftUI
import WidgetKit

/// Kilit ekranı ailelerinde sistem tek renge indirger; gradyan denenmez.
struct RectangularView: View {
    let entry: PrayerEntry
    let alignment: WidgetAlignment

    var body: some View {
        switch entry.content {
        case .noData:
            Text("Vakitler için uygulamayı aç").font(.system(size: 12))
        case .needsUpdate:
            Text("Uygulamayı güncelleyin").font(.system(size: 12))
        case let .ready(next, _, _, _, isStale, isTomorrow):
            ready(next: next, isStale: isStale, isTomorrow: isTomorrow)
        }
    }

    private func ready(next: PrayerSlot, isStale: Bool, isTomorrow: Bool) -> some View {
        VStack(alignment: alignment.horizontal, spacing: 1) {
            if isStale {
                Text("GÜNCEL DEĞİL")
                    .font(.system(size: 10, weight: .semibold))
                    .widgetAccentable()
            }

            HStack(spacing: 4) {
                Text(isTomorrow ? "Yarın \(next.name)" : next.name)
                Text(TimeFormatting.clock(next.date, preference: entry.timeFormat))
                    .monospacedDigit()
            }
            .font(.system(size: 15, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            // "SIRADAKİ" etiketi kalktı; yerini widget'ın asıl işi aldı.
            // Sistemin aralık sayacı: Always-On'da da sayıyor (0.5.4 ölçümü).
            Text(timerInterval: min(entry.date, next.date)...next.date, countsDown: true)
            .font(.system(size: 20, weight: .regular).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment.frame)
        .multilineTextAlignment(alignment.textAlignment)
    }
}
