import SwiftUI
import WidgetKit

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

    private var place: String {
        isStale ? (entry.labels?.stale ?? "Güncel değil") : locationLabel
    }

    var body: some View {
        VStack(alignment: alignment.horizontal, spacing: 1) {
            if let status = entry.kerahat {
                KerahatChip(entry: entry, status: status, palette: palette)
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

/// Üst ve alt bloğu ayıran tam genişlik çizgi. Altına pay vermez: alt bloğun
/// yeri çizgiden itibaren `CenteredBelowDivider` ile ölçülür.
struct WidgetDivider: View {
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
            .padding(.top, 7)
    }
}

/// Alt blok: vakit adı ile saati yan yana, altında ince geri sayım.
struct NextPrayerBlock: View {
    /// Vakit satırı ile sayaç arası; bitişik duruyordu (2026-09-20 tasarımı, B2).
    static let countdownSpacing: CGFloat = 8
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
        VStack(alignment: alignment.horizontal, spacing: Self.countdownSpacing) {
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
        // `Text(timerInterval:)` sunulan genişliği doldurur; metnin kutu içi
        // hizası ayrıca verilmezse sola yaslı kalıyor (2026-09-15 cihaz gözlemi).
        .multilineTextAlignment(alignment.textAlignment)
        .frame(maxWidth: .infinity, alignment: alignment.frame)
    }
}

/// Alt bloğu çizgi ile widget'ın görünen alt kenarı arasında dikeyde ortalar.
/// İçerik alanı sistemin kenar boşluğunda biter; blok o boşluk kadar üstten
/// pay alınca içeriği görünen kenara göre tam ortaya düşer (2026-09-20, B2).
struct CenteredBelowDivider<Content: View>: View {
    @Environment(\.widgetContentMargins) private var margins
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Spacer(minLength: 0)
        content.padding(.top, margins.bottom)
        Spacer(minLength: 0)
    }
}
