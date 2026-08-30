import SwiftUI
import WidgetKit

/// Kilit ekranı ailelerinde sistem tek renge indirger; gradyan denenmez.
struct RectangularView: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
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
                Text(next.date, format: .dateTime.hour().minute())
                    .monospacedDigit()
            }
            .font(.system(size: 15, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            // "SIRADAKİ" etiketi kalktı; yerini widget'ın asıl işi aldı.
            Group {
                if isLuminanceReduced {
                    // SPIKE (0.5.3): bkz. CountdownLabel.
                    Text(
                        timerInterval: min(entry.date, next.date)...next.date,
                        countsDown: true
                    )
                } else {
                    Text(next.date, style: .timer)
                }
            }
            .font(.system(size: 20, weight: .regular).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment.frame)
        .multilineTextAlignment(alignment.textAlignment)
    }
}
