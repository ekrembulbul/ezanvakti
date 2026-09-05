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

        return HStack(alignment: .top, spacing: 14) {
            VStack(alignment: alignment.horizontal, spacing: 0) {
                VStack(alignment: alignment.horizontal, spacing: 1) {
                    if let gregorian = DayLabel.gregorian(day) {
                        Text(gregorian)
                    }
                    Text(
                        [
                            day.hijri,
                            isStale
                                ? (entry.labels?.stale ?? "Güncel değil")
                                : locationLabel,
                        ]
                            .compactMap { $0 }
                            .joined(separator: " · ")
                    )
                }
                .font(.system(size: 12))
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                Text(
                    (isTomorrow
                        ? "\((entry.labels?.tomorrow ?? "Yarın").uppercased()) · "
                        : "")
                        + next.name.uppercased(with: Locale(identifier: "tr_TR"))
                )
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                Text(TimeFormatting.clock(next.date, preference: entry.timeFormat))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)

                CountdownLabel(
                    entry: entry,
                    target: next.date,
                    size: 24,
                    color: palette.textPrimary
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment.frame)
            .multilineTextAlignment(alignment.textAlignment)

            // Altı satır dikeyde yayılıp yüksekliğin tamamını kaplar; 0.5.0'da
            // listenin altında ölü alan kalıyordu. Yatayda ise içeriğine
            // sarılır: sütun genişliğin yarısını kaplayınca satırdaki Spacer
            // adı sola, saati sağa itiyor ve arada bir uçurum kalıyordu.
            VStack(spacing: 0) {
                ForEach(Array(slots.enumerated()), id: \.element.name) { index, slot in
                    if index > 0 { Spacer(minLength: 0) }
                    row(slot: slot, next: next, palette: palette)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxHeight: .infinity)
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
