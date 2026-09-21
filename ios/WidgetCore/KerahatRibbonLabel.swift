import Foundation

/// Widget'taki kerahat şeridinin içeriği: tek kelime ve sistem sayacının hedefi.
///
/// Saf tutuluyor ki XCTest'te sınansın; görünüm (`KerahatRibbon`) etiketi
/// yazar, sonuna sistem sayacını ekler. Saat ya da bitiş yazılmaz: sayaç zaten
/// yaklaşırken başlangıca, kerahatte bitişe sayar (2026-09-19 tasarımı).
enum KerahatRibbonLabel {
    /// Her iki durumda da tek kelime; etiket snapshot'la gelir, yoksa Türkçe.
    /// Yaklaşırken "Kerahate": "Kerahat 09:41" kerahatin sürdüğü gibi
    /// okunuyordu (2026-09-21). Eski uygulama bu kelimeyi göndermez; yine
    /// Türkçe varsayılan.
    static func text(labels: SnapshotLabels?, status: KerahatStatus) -> String {
        switch status {
        case .approaching: return labels?.kerahatSoon ?? "Kerahate"
        case .active: return labels?.kerahat ?? "Kerahat"
        }
    }

    /// Sistem sayacının hedefi: yaklaşırken başlangıç, kerahatte bitiş.
    static func countdownTarget(status: KerahatStatus) -> Date {
        switch status {
        case let .approaching(start, _): return start
        case let .active(end): return end
        }
    }
}
