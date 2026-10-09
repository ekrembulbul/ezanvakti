import SwiftUI

/// Orta widget (2026-10-08, spec K8): her kenarda 14, düzen sabit (hizalama
/// ayarı yalnız küçük boyda). Üstte solda konum, sağda "gün, tarih · hicri";
/// vakit adı ile saati ve sağda sayaç; gün cetveli (`RulerView`); altı vakit
/// yan yana, sıradaki vurgulu, geçenler soluk. Eski payload'da cetvel yok: o
/// alan çizilmez, boşluklar kalan yüksekliği paylaşır.
///
/// Kerahat penceresinde (2026-10-09) konum/tarih satırı kalkar, yerine üst
/// kenardan kenara 30 pt `KerahatBand` gelir; içerik kalan yüksekliği paylaşır.
/// Kerahat sürerken vakit adı ve sayaç bordo tona döner, zemin bordoya kayar
/// (küçük boyla aynı kural).
struct MediumView: View {
    @Environment(\.colorScheme) private var colorScheme

    static let countdownFontSize: CGFloat = 28
    static let countdownInk = InkInsets.system(size: countdownFontSize, weight: .light)
    static let headerHeight: CGFloat = 22

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
        // Kerahat sürerken zemin bordoya kayar; cetvel noktasının halkası da
        // zeminden okuduğu için aynı palet.
        let palette = Palette.resolve(entry.appearance, phase: phase, colorScheme: colorScheme)
            .duringKerahat(active: entry.isKerahatActive)
        // Liste sıradaki vaktin gününü gösterir; `day` bu yüzden timeline'da
        // sıradaki vakte göre seçiliyor. Adlar etiketlerden: `next` de öyle
        // kuruluyor, sıradaki vaktin eşleşmesi buna bağlı.
        let slots = NextPrayer.slots(days: [day], calendar: .current, labels: entry.labels)

        return VStack(spacing: 0) {
            if let status = entry.kerahat {
                KerahatBand(entry: entry, status: status, day: day, palette: palette)
            }
            VStack(spacing: 0) {
                if entry.kerahat == nil {
                    header(day: day, palette: palette, locationLabel: locationLabel, isStale: isStale)
                    Spacer(minLength: 4)
                } else {
                    // Bant ile vakit satırı arası; fazlası boşluklarla paylaşılır.
                    Spacer(minLength: 8)
                }
                prayerRow(next: next, palette: palette, isTomorrow: isTomorrow)
                if let ruler = day.ruler {
                    Spacer(minLength: 2)
                    RulerView(
                        ruler: ruler,
                        palette: palette,
                        nowFraction: RulerGeometry.dayFraction(
                            now: entry.date, day: day.date, calendar: .current))
                }
                Spacer(minLength: 4)
                HStack(spacing: 0) {
                    ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                        column(slot: slot, next: next, palette: palette)
                    }
                }
            }
            // Bant varken üst pay bantta; içerik yine 14'lük yan ve alt payda.
            .padding(.horizontal, WidgetInsets.content)
            .padding(.top, entry.kerahat == nil ? WidgetInsets.content : 0)
            .padding(.bottom, WidgetInsets.content)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(isStale ? 0.55 : 1)
    }

    /// Konum ve tarih; 22 pt yükseklikte sabit. Kerahat penceresinde çizilmez
    /// (yerine `KerahatBand`).
    private func header(
        day: SnapshotDay, palette: Palette, locationLabel: String, isStale: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Text(verbatim: WidgetText.place(locationLabel: locationLabel, isStale: isStale, labels: entry.labels))
                .font(.system(size: 12))
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            if let date = DayLabel.header(day) {
                Text(verbatim: date)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .layoutPriority(1)
            }
        }
        .frame(height: Self.headerHeight)
    }

    /// Solda vakit adı ile saati (aynı taban çizgisinde), sağda sayaç. Sayacın
    /// kutusu mürekkebe indirilir: 28'lik satır kutusu cetvele yer bırakmıyordu.
    private func prayerRow(next: PrayerSlot, palette: Palette, isTomorrow: Bool) -> some View {
        // Yalnız kerahat sürerken; yaklaşırken bant yeter, vakit satırı olağan.
        let inKerahat = entry.isKerahatActive
        return HStack(alignment: .center, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: WidgetText.prayerName(next: next, isTomorrow: isTomorrow, labels: entry.labels))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(inKerahat ? palette.kerahat : palette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(TimeFormatting.clock(next.date, preference: entry.timeFormat))
                    .font(.system(size: 18, weight: .semibold).monospacedDigit())
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
            }
            .layoutPriority(1)
            CountdownLabel(
                entry: entry, target: next.date, size: Self.countdownFontSize,
                color: inKerahat ? palette.kerahat : palette.textPrimary, weight: .light)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .inkBounds(Self.countdownInk)
        }
    }

    /// Ad 10 ve saat 12; sıradaki vurgu zeminli, geçenler soluk.
    private func column(slot: PrayerSlot, next: PrayerSlot, palette: Palette) -> some View {
        let isNext = slot == next
        let isPast = slot.date < entry.date

        return VStack(spacing: 1) {
            Text(verbatim: slot.name)
                .font(.system(size: 10))
                .foregroundStyle(isNext ? palette.accent : palette.textSecondary)
            Text(TimeFormatting.clock(slot.date, preference: entry.timeFormat))
                .font(.system(size: 12, weight: isNext ? .bold : .medium).monospacedDigit())
                .foregroundStyle(isNext ? palette.accent : palette.textPrimary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.vertical, 3)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
        .background {
            if isNext {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(palette.accent.opacity(0.16))
            }
        }
        .opacity(isPast && !isNext ? 0.5 : 1)
    }
}
