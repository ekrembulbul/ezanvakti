import SwiftUI
import WidgetKit

/// Kilit ekranı ailelerinde sistem tek renge indirger; gradyan denenmez.
///
/// Geri sayım yok: `Text(timerInterval:)` kilitli cihazda yanlış kalan süre
/// gösteriyordu (2026-09-14 cihaz gözlemi). Sıradaki vakit büyük, altında
/// bir sonraki vakit; ikisi de kare değişmeden doğru kalır.
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
        case let .ready(next, day, _, _, isStale, isTomorrow):
            ready(next: next, day: day, isStale: isStale, isTomorrow: isTomorrow)
        }
    }

    private func ready(
        next: PrayerSlot, day: SnapshotDay, isStale: Bool, isTomorrow: Bool
    ) -> some View {
        let following = NextPrayer.following(
            after: next, in: day, calendar: .current, labels: entry.labels)

        return VStack(alignment: alignment.horizontal, spacing: 2) {
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

            if let following {
                HStack(spacing: 4) {
                    Text(following.name)
                    Text(TimeFormatting.clock(following.date, preference: entry.timeFormat))
                        .monospacedDigit()
                }
                .font(.system(size: 13, weight: .regular))
                .opacity(0.75)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment.frame)
        .multilineTextAlignment(alignment.textAlignment)
    }
}
