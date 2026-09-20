import SwiftUI

/// Üst bloğun başındaki kerahat şeridi: ikon · "Kerahat" · sistem sayacı.
/// Yaklaşırken turuncu çerçeveli ve sayaç başlangıca, kerahatte bordo dolgulu
/// ve sayaç bitişe sayar. Alt bloktaki sayaç bundan bağımsız, sıradaki vakte.
struct KerahatChip: View {
    let entry: PrayerEntry
    let status: KerahatStatus
    let palette: Palette

    private var isActive: Bool { entry.isKerahatActive }
    private var foreground: Color { isActive ? .white : palette.kerahatSoonText }

    /// Pencere 30 dk, aralıklar 45 dk altı: sayaç hep dk:sn.
    private var countdown: Text {
        let target = KerahatChipLabel.countdownTarget(status: status)
        return Text(timerInterval: min(entry.date, target)...target, countsDown: true)
            .font(.system(size: 11, weight: .bold).monospacedDigit())
    }

    var body: some View {
        // Tek `Text`: sistem sayacı sunulan genişliği doldurup içeriğini sola
        // yaslıyor (2026-09-15 cihaz gözlemi); ikon, kelime ve sayaç aynı
        // metinde birleşince ortalı hiza bütününe uygulanır.
        (Text(Image(systemName: "sun.horizon"))
            + Text(verbatim: " \(KerahatChipLabel.text(labels: entry.labels)) ")
            + countdown)
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.center)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 22)
            .background(Capsule().fill(isActive ? palette.kerahatLine : palette.kerahatSoonSurface))
            .overlay(Capsule().strokeBorder(isActive ? palette.kerahatLine : palette.kerahatSoonLine, lineWidth: 1))
    }
}
