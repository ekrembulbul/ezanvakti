import SwiftUI

/// Widget'ın en altındaki tam genişlik kerahat şeridi: ikon · kelime · sistem
/// sayacı. Kenar payının dışında durur; köşelerini widget'ın kendi yuvarlağı
/// kırpar (2026-09-20 tasarımı: üst bloktaki kapsül tarihi tek satıra
/// indiriyordu, tarih artık her durumda üç satır). Yaklaşırken turuncu zemin
/// ve üstte turuncu çizgi, kelime "Kerahate", sayaç başlangıca; kerahatte
/// bordo dolgu, "Kerahat", sayaç bitişe. Alt bloktaki sayaç bundan bağımsız,
/// sıradaki vakte. Yazı 15 (13 küçük kalıyordu) ve şerit 32 (26 basık
/// duruyordu; 2026-09-21, seçenek B). Alt blok boşlukları şeride göre
/// yeniden eşitlenir.
struct KerahatRibbon: View {
    static let height: CGFloat = 32
    static let fontSize: CGFloat = 15

    let entry: PrayerEntry
    let status: KerahatStatus
    let palette: Palette

    private var isActive: Bool { entry.isKerahatActive }
    private var foreground: Color { isActive ? .white : palette.kerahatSoonText }

    /// Pencere 30 dk, aralıklar 45 dk altı: sayaç hep dk:sn.
    private var countdown: Text {
        let target = KerahatRibbonLabel.countdownTarget(status: status)
        return Text(timerInterval: min(entry.date, target)...target, countsDown: true)
            .font(.system(size: Self.fontSize, weight: .bold).monospacedDigit())
    }

    var body: some View {
        // Tek `Text`: sistem sayacı sunulan genişliği doldurup içeriğini sola
        // yaslıyor (2026-09-15 cihaz gözlemi); ikon, kelime ve sayaç aynı
        // metinde birleşince ortalı hiza bütününe uygulanır.
        (Text(Image(systemName: "sun.horizon"))
            + Text(verbatim: " \(KerahatRibbonLabel.text(labels: entry.labels, status: status)) ")
            + countdown)
            .font(.system(size: Self.fontSize, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.center)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: Self.height)
            .background(isActive ? palette.kerahatLine : palette.kerahatSoonSurface)
            .overlay(alignment: .top) {
                if !isActive {
                    palette.kerahatSoonLine.frame(height: 1)
                }
            }
    }
}
