import SwiftUI

/// Üst bloğun başındaki kerahat şeridi: yaklaşırken çerçeveli, kerahatte dolgulu.
struct KerahatChip: View {
    let entry: PrayerEntry
    let status: KerahatStatus
    let palette: Palette
    var compact = true

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sun.horizon")
            Text(KerahatChipLabel.text(
                status: status, compact: compact,
                labels: entry.labels, timeFormat: entry.timeFormat))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(entry.isKerahatActive ? Color.white : palette.kerahat)
        .frame(maxWidth: .infinity)
        .frame(height: 22)
        .background(Capsule().fill(entry.isKerahatActive ? palette.kerahatLine : palette.kerahatSurface))
        .overlay(Capsule().strokeBorder(palette.kerahatLine, lineWidth: 1))
    }
}
