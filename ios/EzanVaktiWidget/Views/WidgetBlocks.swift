import SwiftUI
import WidgetKit

// Küçük ve orta widget'ın ortak parçaları (2026-10-08 tasarımı, spec K6/K8):
// iç boşluk, vakit adı, kerahat renkleri ve kerahat sayacı. Kerahat artık alt
// kenardaki şeritte değil; küçükte alt yuvadaki kartta (`KerahatCard`), ortada
// sağ üstteki çipte (`KerahatChip`).

/// Ana ekran ailelerinin kendi kenar payı; sistemin payı kapalı
/// (`contentMarginsDisabled`). Hazır içerik her kenarda `WidgetInsets.content`
/// kullanır; mesajlar dikeyde 12, yatayda sistemin değeriyle ortalanır.
enum WidgetInsets {
    static let vertical: CGFloat = 12
    /// Küçük ve orta boyun hazır içeriğinde her kenar (spec K6/K8).
    static let content: CGFloat = 14
}

/// Mesaj görünümlerinin payı: dikeyde 12, yatayda sistemin değeri.
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

enum WidgetText {
    /// Vakit adı büyük harf; sıradaki vakit yarınsa "YARIN · " öneki.
    static func prayerName(next: PrayerSlot, isTomorrow: Bool, labels: SnapshotLabels?) -> String {
        (isTomorrow ? "\((labels?.tomorrow ?? "Yarın").uppercased()) · " : "")
            + next.name.uppercased(with: Locale(identifier: "tr_TR"))
    }

    /// Konum; çizelge tükendiyse yerine "Güncel değil".
    static func place(locationLabel: String, isStale: Bool, labels: SnapshotLabels?) -> String {
        isStale ? (labels?.stale ?? "Güncel değil") : locationLabel
    }
}

/// Kerahat kartı ve çipinin renkleri: yaklaşırken turuncu, kerahatte bordo.
/// İkisi aynı rengi kullanır ki küçük ve orta boy aynı dili konuşsun.
struct KerahatTone {
    let surface: Color
    let text: Color

    init(status: KerahatStatus, palette: Palette) {
        switch status {
        case .approaching:
            surface = palette.kerahatSoonSurface
            text = palette.kerahatSoonText
        case .active:
            surface = palette.kerahatSurface
            text = palette.kerahat
        }
    }
}

/// Kerahat sayacı: yaklaşırken başlangıca, kerahatte bitişe sayan sistem
/// sayacı (`Text(timerInterval:)`; Always-On'da da sistem çizer).
///
/// Pencere 30 dk, aralıklar 45 dk altı: sayaç hep dk:sn. Sistem sayacı
/// sunulan genişliği doldurup içeriğini sola yaslıyor (2026-09-15 cihaz
/// gözlemi); en geniş hâlin ("00:00") görünmez kalıbı genişliği sabitler,
/// sayaç onun üstünde sağa yaslı durur.
struct KerahatCountdown: View {
    let entry: PrayerEntry
    let status: KerahatStatus
    let size: CGFloat
    var weight: Font.Weight = .medium

    var body: some View {
        let target = KerahatRibbonLabel.countdownTarget(status: status)
        let font = Font.system(size: size, weight: weight).monospacedDigit()
        return Text(verbatim: "00:00")
            .font(font)
            .hidden()
            .overlay(alignment: .trailing) {
                Text(timerInterval: min(entry.date, target)...target, countsDown: true)
                    .font(font)
                    .multilineTextAlignment(.trailing)
            }
            .lineLimit(1)
    }
}

extension View {
    /// Yerleşim kutusunu mürekkebe (rakam üstü–taban çizgisi) indirir; çizim
    /// aynı kalır, kutu dışına taşar.
    func inkBounds(_ insets: InkInsets) -> some View {
        padding(.top, -insets.top).padding(.bottom, -insets.bottom)
    }
}
