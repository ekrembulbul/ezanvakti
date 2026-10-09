import SwiftUI

/// Küçük widget'ın alt yuvasındaki kerahat kartı (spec K6): solda kelime ve
/// aralığın saatleri ("12:47 – 12:57"), sağda sistem sayacı. Yaklaşırken
/// turuncu dolgu ve turuncu iç kenarlık ("Kerahate", sayaç başlangıca);
/// kerahat sürerken bordo dolgu ve beyaz yazı ("Kerahat", sayaç bitişe;
/// 2026-10-09). Yuva kerahat yokken tarih ile hicri tarihi taşır; kart aynı
/// yüksekliktedir ki üstteki vakit bloğu kımıldamasın.
struct KerahatCard: View {
    static let height: CGFloat = 34
    static let cornerRadius: CGFloat = 12

    let entry: PrayerEntry
    let status: KerahatStatus
    let day: SnapshotDay
    let palette: Palette

    var body: some View {
        let tone = KerahatTone(status: status, palette: palette)
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        return HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: KerahatRibbonLabel.text(labels: entry.labels, status: status))
                    .font(.system(size: 12, weight: .semibold))
                if let range = Self.range(status: status, day: day, preference: entry.timeFormat) {
                    Text(verbatim: range)
                        .font(.system(size: 10).monospacedDigit())
                        .opacity(tone.rangeOpacity)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            KerahatCountdown(entry: entry, status: status, size: 16)
        }
        .foregroundStyle(tone.text)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .background(shape.fill(tone.fill))
        // İç kenarlık: kartı büyütmez, yuva 34 pt kalır.
        .overlay {
            if let border = tone.border {
                shape.strokeBorder(border, lineWidth: KerahatTone.borderWidth)
            }
        }
    }

    /// Aralığın saatleri. Yaklaşırken durum başlangıcı taşır; kerahatte
    /// yalnız bitişi taşır, başlangıç gösterilen günün aralıklarından bitişi
    /// eşleşen aralıkla bulunur (kerahat hep gündüz, sıradaki vaktin gününde).
    /// Bulunamazsa satır çizilmez, kelime ile sayaç yeter.
    static func range(
        status: KerahatStatus, day: SnapshotDay, preference: TimeFormatPreference
    ) -> String? {
        let start: Date
        let end: Date
        switch status {
        case let .approaching(intervalStart, intervalEnd):
            start = intervalStart
            end = intervalEnd
        case let .active(intervalEnd):
            guard let match = KerahatStatus.intervals(days: [day], calendar: .current)
                .first(where: { $0.end == intervalEnd })
            else { return nil }
            start = match.start
            end = intervalEnd
        }
        return "\(TimeFormatting.clock(start, preference: preference)) – "
            + TimeFormatting.clock(end, preference: preference)
    }
}
