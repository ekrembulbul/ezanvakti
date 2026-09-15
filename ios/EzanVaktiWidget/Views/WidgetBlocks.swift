import SwiftUI

// Küçük widget'ın ve orta widget'ın sol sütununun ortak parçaları.
// Sıra: üst blok · çizgi · vakit adı ile saat yan yana · ince sayaç.

/// Üst blok: kerahat yokken tarih, hicri tarih ve konum; kerahat yaklaşırken ya
/// da sürerken çip ve tek satırda kısa tarih ile konum.
struct WidgetHeader: View {
    let entry: PrayerEntry
    let day: SnapshotDay
    let palette: Palette
    let alignment: WidgetAlignment
    let locationLabel: String
    let isStale: Bool
    var compact = true

    private var place: String {
        isStale ? (entry.labels?.stale ?? "Güncel değil") : locationLabel
    }

    var body: some View {
        VStack(alignment: alignment.horizontal, spacing: 1) {
            if let status = entry.kerahat {
                KerahatChip(entry: entry, status: status, palette: palette, compact: compact)
                    .padding(.bottom, 5)
                Text([DayLabel.short(day), place].compactMap { $0 }.joined(separator: " · "))
            } else {
                if let gregorian = DayLabel.gregorian(day) {
                    Text(gregorian)
                }
                if let hijri = day.hijri {
                    Text(hijri)
                }
                Text(place)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(palette.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .multilineTextAlignment(alignment.textAlignment)
        .frame(maxWidth: .infinity, alignment: alignment.frame)
    }
}

/// Üst ve alt bloğu ayıran tam genişlik çizgi.
struct WidgetDivider: View {
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
            .padding(.top, 7)
            .padding(.bottom, 12)
    }
}

/// Alt blok: vakit adı ile saati yan yana, altında ince geri sayım.
struct NextPrayerBlock: View {
    let entry: PrayerEntry
    let next: PrayerSlot
    let palette: Palette
    let alignment: WidgetAlignment
    let isTomorrow: Bool

    private var name: String {
        (isTomorrow ? "\((entry.labels?.tomorrow ?? "Yarın").uppercased()) · " : "")
            + next.name.uppercased(with: Locale(identifier: "tr_TR"))
    }

    var body: some View {
        VStack(alignment: alignment.horizontal, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(TimeFormatting.clock(next.date, preference: entry.timeFormat))
                    .font(.system(size: 16, weight: .semibold).monospacedDigit())
                    .foregroundStyle(palette.textPrimary)
            }
            CountdownLabel(
                entry: entry, target: next.date, size: 26,
                color: palette.textPrimary, weight: .light)
        }
        .frame(maxWidth: .infinity, alignment: alignment.frame)
    }
}
