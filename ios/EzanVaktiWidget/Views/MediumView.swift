import SwiftUI

struct MediumView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: PrayerEntry

    var body: some View {
        switch entry.content {
        case .noData:
            MessageView(text: "Vakitler için uygulamayı aç", phase: .fallback)
        case .needsUpdate:
            MessageView(text: "Uygulamayı güncelleyin", phase: .fallback)
        case let .ready(next, day, phase, locationLabel, isStale, _):
            ready(
                next: next, day: day, phase: phase,
                locationLabel: locationLabel, isStale: isStale
            )
        }
    }

    private func ready(
        next: PrayerSlot, day: SnapshotDay, phase: DayPhase,
        locationLabel: String, isStale: Bool
    ) -> some View {
        let palette = Palette.forPhase(phase, colorScheme: colorScheme)
        let slots = NextPrayer.slots(days: [day], calendar: .current)

        return HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                // Cihaz dili Turkce degilse localizedUppercase "i" harfini
            // noktasiz "I" yapiyor; uygulama tamamen Turkce oldugu icin
            // buyuk harf donusumu tr_TR ile zorlaniyor.
            Text(next.name.uppercased(with: Locale(identifier: "tr_TR")))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accent)

                Text(next.date, format: .dateTime.hour().minute())
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)

                Text(next.date, style: .timer)
                    .font(.system(size: 22, weight: .light).monospacedDigit())
                    .foregroundStyle(palette.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(isStale ? "Güncel değil" : locationLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 3) {
                ForEach(slots, id: \.name) { slot in
                    row(slot: slot, next: next, palette: palette)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .opacity(isStale ? 0.55 : 1)
    }

    /// Geçmiş vakitler soluk, sıradaki accent ile vurgulu.
    private func row(slot: PrayerSlot, next: PrayerSlot, palette: Palette) -> some View {
        let isNext = slot == next
        let isPast = slot.date < entry.date
        let weight: Font.Weight = isNext ? .semibold : .regular

        return HStack {
            Text(slot.name)
                .font(.system(size: 11, weight: weight))
            Spacer(minLength: 6)
            Text(slot.date, format: .dateTime.hour().minute())
                .font(.system(size: 11, weight: weight).monospacedDigit())
        }
        .foregroundStyle(
            isNext
                ? palette.accent
                : (isPast ? palette.textSecondary.opacity(0.5) : palette.textPrimary)
        )
    }
}
