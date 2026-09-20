import Foundation

/// Widget'taki kerahat çipinin içeriği: tek kelime ve sistem sayacının hedefi.
///
/// Saf tutuluyor ki XCTest'te sınansın; görünüm (`KerahatChip`) etiketi yazar,
/// sonuna sistem sayacını ekler. Saat ya da bitiş yazılmaz: sayaç zaten
/// yaklaşırken başlangıca, kerahatte bitişe sayar (2026-09-19 tasarımı).
enum KerahatChipLabel {
    /// Her iki durumda da tek kelime; etiket snapshot'la gelir, yoksa Türkçe.
    static func text(labels: SnapshotLabels?) -> String {
        labels?.kerahat ?? "Kerahat"
    }

    /// Sistem sayacının hedefi: yaklaşırken başlangıç, kerahatte bitiş.
    static func countdownTarget(status: KerahatStatus) -> Date {
        switch status {
        case let .approaching(start, _): return start
        case let .active(end): return end
        }
    }
}
