import SwiftUI
import WidgetKit

/// Kilit ekranı ailelerinde sistem tek renge indirger; gradyan denenmez.
///
/// Sıradaki vakit, saati ve altında geri sayım. Always-On ekranda
/// (`isLuminanceReduced`) sayaç görünmez ama yeri korunur: `Text(timerInterval:)`
/// orada yanlış kalan süre gösteriyordu (2026-09-14 cihaz gözlemi); başlık iki
/// durumda da aynı yerde durur, ekran uyanınca zıplamaz. Kare her vakit
/// geçişinde yenilenir.
struct RectangularView: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

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
        // Vakit satırı 17 ve sayaçla arası 4: 15/1 sıkışık ve küçük duruyordu
        // (2026-09-21).
        VStack(alignment: alignment.horizontal, spacing: 4) {
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

            // `hidden` yerleşimi korur; `if` başlığı dikeyde kaydırırdı.
            Text(timerInterval: min(entry.date, next.date)...next.date, countsDown: true)
                .font(.system(size: 20, weight: .regular).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .opacity(isLuminanceReduced ? 0 : 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment.frame)
        .multilineTextAlignment(alignment.textAlignment)
    }
}
