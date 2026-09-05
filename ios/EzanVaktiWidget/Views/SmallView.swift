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
            // Üst blok: ikincil bilgi, küçük punto.
            VStack(alignment: alignment.horizontal, spacing: 1) {
                if let gregorian = DayLabel.gregorian(day) {
                    Text(gregorian)
                }
                if let hijri = day.hijri {
                    Text(hijri)
                }
                Text(
                    isStale
                        ? (entry.labels?.stale ?? "Güncel değil")
                        : locationLabel)
            }
            .font(.system(size: 12))
            .foregroundStyle(palette.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Spacer(minLength: 4)

            // Alt blok: widget'ın asıl işi.
            VStack(alignment: alignment.horizontal, spacing: 0) {
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
                    size: 26,
                    color: palette.textPrimary
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment.frame)
        .multilineTextAlignment(alignment.textAlignment)
        .opacity(isStale ? 0.55 : 1)
    }
}
