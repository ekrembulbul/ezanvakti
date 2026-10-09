import SwiftUI

/// Orta boyun üst kenarındaki kerahat bandı (spec K8, 2026-10-09; dosya adı
/// eski `KerahatChip`'ten kaldı). Kerahat penceresinde konum ve tarih satırının
/// yerine widget'ın üst kenarından kenara uzanır; köşeleri widget'ın kendi
/// yuvarlak köşesi kırpar. Solda kelime ve aralığın saatleri ("18:40 –
/// 19:23"), sağda sistem sayacı. Renkler küçük boydaki kartla aynı
/// (`KerahatTone`): kerahat sürerken bordo dolgu ve beyaz yazı, yaklaşırken
/// turuncu dolgu ve altta turuncu çizgi.
struct KerahatBand: View {
    static let height: CGFloat = 30

    let entry: PrayerEntry
    let status: KerahatStatus
    let day: SnapshotDay
    let palette: Palette

    var body: some View {
        let tone = KerahatTone(status: status, palette: palette)
        return HStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(verbatim: KerahatRibbonLabel.text(labels: entry.labels, status: status))
                    .font(.system(size: 12, weight: .semibold))
                if let range = KerahatCard.range(status: status, day: day, preference: entry.timeFormat) {
                    Text(verbatim: range)
                        .font(.system(size: 10.5).monospacedDigit())
                        .opacity(tone.rangeOpacity)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            KerahatCountdown(entry: entry, status: status, size: 15, weight: .bold)
        }
        .foregroundStyle(tone.text)
        // Yazılar ana içerikle aynı hizada; yalnız dolgu tam genişlik.
        .padding(.horizontal, WidgetInsets.content)
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .background(tone.fill)
        .overlay(alignment: .bottom) {
            if let border = tone.border {
                Rectangle()
                    .fill(border)
                    .frame(height: KerahatTone.borderWidth)
            }
        }
    }
}
