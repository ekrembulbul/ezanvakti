import SwiftUI

/// Küçük widget (2026-10-08, spec K6): her kenarda 14. Üstte konum; ortada
/// vakit adı ile saati ve büyük sayaç; altta sabit yuva — kerahat yokken
/// "gün, tarih" ve hicri tarih, kerahat penceresinde `KerahatCard`. Kart alt
/// yuvayı aldığında tarih üst satıra konumun yanına geçer ("konum · tarih");
/// tarih iki yerde birden görünmez (2026-10-09). Kerahat sürerken vakit adı
/// ve sayaç bordo tona döner, zemin bordoya kayar.
///
/// Hizalama ayarı (sola / ortaya / sağa) yalnız bu boyda geçerli; kart her
/// durumda tam genişlik.
struct SmallView: View {
    @Environment(\.colorScheme) private var colorScheme

    let entry: PrayerEntry
    let alignment: WidgetAlignment

    var body: some View {
        switch entry.content {
        case .noData:
            MessageView(text: "Vakitler için uygulamayı aç", phase: .fallback, appearance: entry.appearance)
                .modifier(HomeContentInsets())
        case .needsUpdate:
            MessageView(text: "Uygulamayı güncelleyin", phase: .fallback, appearance: entry.appearance)
                .modifier(HomeContentInsets())
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
        // Kerahat sürerken zemin bordoya kayar; zemini okuyan her parça aynı palet.
        let palette = Palette.resolve(entry.appearance, phase: phase, colorScheme: colorScheme)
            .duringKerahat(active: entry.isKerahatActive)
        let place = WidgetText.place(locationLabel: locationLabel, isStale: isStale, labels: entry.labels)
        // Tarih kerahat yokken alt yuvada; kart yuvayı alınca üst satıra geçer.
        let top = entry.kerahat == nil
            ? place
            : [place, DayLabel.short(day)].compactMap { $0 }.joined(separator: " · ")
        // Yalnız kerahat sürerken; yaklaşırken kart yeter, vakit bloğu olağan.
        let inKerahat = entry.isKerahatActive

        // Üst satır ile yuva arasındaki iki eşit boşluk vakit bloğunu ortalar.
        return VStack(alignment: alignment.horizontal, spacing: 0) {
            Text(verbatim: top)
                .font(.system(size: 12))
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: WidgetText.prayerName(next: next, isTomorrow: isTomorrow, labels: entry.labels))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(inKerahat ? palette.kerahat : palette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(TimeFormatting.clock(next.date, preference: entry.timeFormat))
                    .font(.system(size: 16, weight: .semibold).monospacedDigit())
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
            }
            CountdownLabel(
                entry: entry, target: next.date, size: 34,
                color: inKerahat ? palette.kerahat : palette.textPrimary, weight: .light)
                .padding(.top, 2)
            Spacer(minLength: 0)
            bottomSlot(day: day, palette: palette)
        }
        .padding(WidgetInsets.content)
        // `Text(timerInterval:)` sunulan genişliği doldurur; metnin kutu içi
        // hizası ayrıca verilmezse sola yaslı kalıyor (2026-09-15 cihaz gözlemi).
        .multilineTextAlignment(alignment.textAlignment)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment.frame)
        .opacity(isStale ? 0.55 : 1)
    }

    /// 34 pt sabit yuva: kerahat yokken "gün, tarih" (`"Cuma, 9 Ekim"`) ve
    /// hicri tarih, varsa kart.
    @ViewBuilder
    private func bottomSlot(day: SnapshotDay, palette: Palette) -> some View {
        if let status = entry.kerahat {
            KerahatCard(entry: entry, status: status, day: day, palette: palette)
        } else {
            VStack(alignment: alignment.horizontal, spacing: 0) {
                if let date = DayLabel.gregorian(day) {
                    Text(verbatim: date)
                }
                if let hijri = day.hijri {
                    Text(verbatim: hijri)
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(palette.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment.horizontal, vertical: .bottom))
            .frame(height: KerahatCard.height, alignment: .bottom)
        }
    }
}
