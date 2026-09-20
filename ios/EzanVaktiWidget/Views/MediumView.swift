import SwiftUI

struct MediumView: View {
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
        // Liste sıradaki vaktin gününü gösterir; `day` bu yüzden timeline'da
        // sıradaki vakte göre seçiliyor.
        let slots = NextPrayer.slots(days: [day], calendar: .current)

        return HStack(spacing: 0) {
            // Sol sütun küçük widget'ın aynısı; genişliği sabit ki liste
            // cihazdan cihaza değişen artığı alsın.
            VStack(alignment: alignment.horizontal, spacing: 0) {
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
            .frame(width: 158)

            Rectangle()
                .fill(palette.textSecondary.opacity(0.2))
                .frame(width: 1)
                .padding(.leading, 14)
                .padding(.trailing, 16)

            // Altı satır dikeyde yayılıp yüksekliğin tamamını kaplar; sütun
            // artan genişliği alır.
            VStack(spacing: 0) {
                ForEach(Array(slots.enumerated()), id: \.element.name) { index, slot in
                    if index > 0 { Spacer(minLength: 0) }
                    row(slot: slot, next: next, palette: palette)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(isStale ? 0.55 : 1)
    }

    /// Geçmiş vakitler soluk, sıradaki accent ile vurgulu.
    private func row(slot: PrayerSlot, next: PrayerSlot, palette: Palette) -> some View {
        let isNext = slot == next
        let isPast = slot.date < entry.date
        let weight: Font.Weight = isNext ? .semibold : .regular

        return HStack(spacing: 0) {
            Text(slot.name)
                .font(.system(size: 12, weight: weight))
            Spacer(minLength: 12)
            Text(TimeFormatting.clock(slot.date, preference: entry.timeFormat))
                .font(.system(size: 12, weight: weight).monospacedDigit())
        }
        .lineLimit(1)
        .foregroundStyle(
            isNext
                ? palette.accent
                : (isPast ? palette.textSecondary.opacity(0.5) : palette.textPrimary)
        )
    }
}
