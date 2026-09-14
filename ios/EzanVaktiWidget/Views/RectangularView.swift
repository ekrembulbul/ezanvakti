import SwiftUI
import WidgetKit

/// Kilit ekranı ailelerinde sistem tek renge indirger; gradyan denenmez.
///
/// Yalnız sıradaki vakit ve saati; geri sayım yok. `Text(timerInterval:)`
/// kilitli cihazda yanlış kalan süre gösteriyordu (2026-09-14 cihaz
/// gözlemi). Satır üste yaslanır, sayacın yeri boş kalır; kare her vakit
/// geçişinde yenilenir.
struct RectangularView: View {
    let entry: PrayerEntry
    let alignment: WidgetAlignment

    var body: some View {
        switch entry.content {
        case .noData:
            Text(entry.labels?.openApp ?? "Vakitler için uygulamayı aç")
                .font(.system(size: 12))
        case .needsUpdate:
            Text(entry.labels?.updateApp ?? "Uygulamayı güncelleyin")
                .font(.system(size: 12))
        case let .ready(next, _, _, _, isStale, isTomorrow):
            ready(next: next, isStale: isStale, isTomorrow: isTomorrow)
        }
    }

    private func ready(next: PrayerSlot, isStale: Bool, isTomorrow: Bool) -> some View {
        VStack(alignment: alignment.horizontal, spacing: 1) {
            if isStale {
                Text((entry.labels?.stale ?? "Güncel değil").uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .widgetAccentable()
            }

            HStack(spacing: 4) {
                Text(
                    isTomorrow
                        ? "\(entry.labels?.tomorrow ?? "Yarın") \(next.name)"
                        : next.name)
                Text(TimeFormatting.clock(next.date, preference: entry.timeFormat))
                    .monospacedDigit()
            }
            .font(.system(size: 17, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(
            maxWidth: .infinity, maxHeight: .infinity,
            alignment: Alignment(horizontal: alignment.horizontal, vertical: .top)
        )
        .multilineTextAlignment(alignment.textAlignment)
    }
}
