import SwiftUI

struct SmallView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: PrayerEntry

    var body: some View {
        switch entry.content {
        case .noData:
            MessageView(text: "Vakitler için uygulamayı aç", phase: .fallback)
        case .needsUpdate:
            MessageView(text: "Uygulamayı güncelleyin", phase: .fallback)
        case let .ready(next, _, phase, locationLabel, isStale, _):
            ready(next: next, phase: phase, locationLabel: locationLabel, isStale: isStale)
        }
    }

    private func ready(
        next: PrayerSlot, phase: DayPhase, locationLabel: String, isStale: Bool
    ) -> some View {
        let palette = Palette.forPhase(phase, colorScheme: colorScheme)

        return VStack(alignment: .leading, spacing: 2) {
            // Cihaz dili Turkce degilse localizedUppercase "i" harfini
            // noktasiz "I" yapiyor; uygulama tamamen Turkce oldugu icin
            // buyuk harf donusumu tr_TR ile zorlaniyor.
            Text(next.name.uppercased(with: Locale(identifier: "tr_TR")))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.accent)

            Text(next.date, format: .dateTime.hour().minute())
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(palette.textPrimary)

            // Sistem bu metni reload'suz, saniye saniye kendisi çiziyor.
            Text(next.date, style: .timer)
                .font(.system(size: 26, weight: .light).monospacedDigit())
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
        .opacity(isStale ? 0.55 : 1)
    }
}
