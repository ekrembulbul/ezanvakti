import SwiftUI

/// Orta boyun sağ üstünde, kerahat penceresinde tarihin yerine geçen kapsül
/// (spec K8, taslak A): kelime + sistem sayacı ("Kerahate 04:12" / "Kerahat
/// 05:51"). Renkler küçük boydaki kartla aynı (`KerahatTone`). Orta boyda ayrı
/// kart sığmıyor: konum, vakit satırı, cetvel ve altı vakit yüksekliği
/// dolduruyor.
struct KerahatChip: View {
    static let height: CGFloat = 22

    let entry: PrayerEntry
    let status: KerahatStatus
    let palette: Palette

    var body: some View {
        let tone = KerahatTone(status: status, palette: palette)
        return HStack(spacing: 6) {
            Text(verbatim: KerahatRibbonLabel.text(labels: entry.labels, status: status))
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            KerahatCountdown(entry: entry, status: status, size: 12, weight: .semibold)
        }
        .foregroundStyle(tone.text)
        .padding(.horizontal, 10)
        .frame(height: Self.height)
        .background(Capsule().fill(tone.surface))
        .fixedSize(horizontal: true, vertical: false)
    }
}
