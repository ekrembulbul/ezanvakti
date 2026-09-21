import SwiftUI
import WidgetKit

// Küçük widget'ın ve orta widget'ın sol sütununun ortak parçaları.
// Sıra: üst blok · çizgi · vakit adı ile saat yan yana · ince sayaç; kerahat
// yaklaşırken ya da sürerken en altta, kenar payının dışında `KerahatRibbon`.
// Alt blok çizgi ile alt sınır (şerit ya da görünen alt kenar) arasında üç
// eşit görünen boşlukla durur; ölçü mürekkepten (`InkInsets`).

/// Ana ekran ailelerinin kendi kenar payı; sistemin payı kapalı
/// (`contentMarginsDisabled`). Dikeyde 12: sistemin 16'sı üç satır tarih,
/// çizgi, vakit satırı, sayaç ve kerahat şeridini birlikte sığdırmıyordu.
/// Yatayda sistemin değeri (`widgetContentMargins`) aynen kullanılır.
enum WidgetInsets {
    static let vertical: CGFloat = 12
}

/// Ana ekran içeriğinin payı: üstte 12, yatayda sistemin değeri; altta
/// verilen kadar. Hazır içerikte 0: alt bloğun sınırı kerahat yokken
/// widget'ın görünen alt kenarı, kerahatte bitişik şeridin üstüdür; mesajlar
/// 12 ile ortalanır.
struct HomeContentInsets: ViewModifier {
    @Environment(\.widgetContentMargins) private var margins
    var bottom: CGFloat = WidgetInsets.vertical

    func body(content: Content) -> some View {
        content
            .padding(.top, WidgetInsets.vertical)
            .padding(.bottom, bottom)
            .padding(.leading, margins.leading)
            .padding(.trailing, margins.trailing)
    }
}

/// Üst blok: tarih, hicri tarih ve konum — kerahatte de aynı üç satır.
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
            if let gregorian = DayLabel.gregorian(day) {
                Text(gregorian)
            }
            if let hijri = day.hijri {
                Text(hijri)
            }
            Text(place)
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
/// boşlukları çizgiden itibaren `NextPrayerBlock` içinde ölçülür.
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
///
/// Sunulan yüksekliği doldurur (çizginin altından alt sınıra kadar) ve üç
/// boşluğu — çizgi–vakit satırı, vakit satırı–sayaç, sayaç–alt sınır — göze
/// eşit dağıtır: metin kutuları `InkInsets` ile rakam yüksekliğine indirilir,
/// kalanı üç eşit `Spacer` paylaşır. Kutudan ölçülünce 27/18/29 görünüyordu
/// (2026-09-21; öncesi B2, çizgi–alt kenar arası ortalı).
struct NextPrayerBlock: View {
    static let rowFontSize: CGFloat = 16
    static let countdownFontSize: CGFloat = 26
    static let rowInk = InkInsets.system(size: rowFontSize, weight: .semibold)
    static let countdownInk = InkInsets.system(size: countdownFontSize, weight: .light)
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
            Spacer(minLength: 0)
            // Satırın kutusu saatin (16) kutusudur: ad aynı taban çizgisinde,
            // daha kısa.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(TimeFormatting.clock(next.date, preference: entry.timeFormat))
                    .font(.system(size: Self.rowFontSize, weight: .semibold).monospacedDigit())
                    .foregroundStyle(palette.textPrimary)
            }
            .inkBounds(Self.rowInk)
            Spacer(minLength: 0)
            CountdownLabel(
                entry: entry, target: next.date, size: Self.countdownFontSize,
                color: palette.textPrimary, weight: .light)
                .inkBounds(Self.countdownInk)
            Spacer(minLength: 0)
        }
        // `Text(timerInterval:)` sunulan genişliği doldurur; metnin kutu içi
        // hizası ayrıca verilmezse sola yaslı kalıyor (2026-09-15 cihaz gözlemi).
        .multilineTextAlignment(alignment.textAlignment)
        .frame(maxWidth: .infinity, alignment: alignment.frame)
    }
}

extension View {
    /// Yerleşim kutusunu mürekkebe (rakam üstü–taban çizgisi) indirir; çizim
    /// aynı kalır, kutu dışına taşar.
    func inkBounds(_ insets: InkInsets) -> some View {
        padding(.top, -insets.top).padding(.bottom, -insets.bottom)
    }
}
