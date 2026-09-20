import SwiftUI

struct SmallView: View {
    @Environment(\.colorScheme) private var colorScheme

    let entry: PrayerEntry
    let alignment: WidgetAlignment

    var body: some View {
        switch entry.content {
        case .noData:
            MessageView(text: "Vakitler için uygulamayı aç", phase: .fallback, appearance: entry.appearance)
        case .needsUpdate:
            MessageView(text: "Uygulamayı güncelleyin", phase: .fallback, appearance: entry.appearance)
        case let .ready(next, day, phase, locationLabel, isStale, isTomorrow):
            ready(
                next: next, day: day, phase: phase,
                locationLabel: locationLabel, isStale: isStale, isTomorrow: isTomorrow
            )
        }
    }

    private func ready(
        next: PrayerSlot, day: SnapshotDay, phase: DayPhase,
        locationLabel: String, isStale: Bool, isTomorrow: Bool
    ) -> some View {
        let palette = Palette.resolve(entry.appearance, phase: phase, colorScheme: colorScheme)

        return VStack(alignment: alignment.horizontal, spacing: 0) {
            WidgetHeader(
                entry: entry, day: day, palette: palette, alignment: alignment,
                locationLabel: locationLabel, isStale: isStale)
            WidgetDivider(color: palette.divider)
            // Alt blok çizgi ile alt kenar arasında dikeyde ortalı; altta
            // boş kalan şerit iki yana dağılır (2026-09-19 cihaz gözlemi).
            Spacer(minLength: 0)
            NextPrayerBlock(
                entry: entry, next: next, palette: palette,
                alignment: alignment, isTomorrow: isTomorrow)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(isStale ? 0.55 : 1)
    }
}
