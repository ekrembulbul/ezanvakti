import SwiftUI

/// Ana ekran widget'larında blokların yatay hizası.
///
/// `AppEnum` uyumu widget target'ındaki `EzanVaktiWidgetIntent.swift`'te
/// extension olarak veriliyor; bu dosya AppIntents'e bağımlı değil ki
/// XCTest'te sınanabilsin.
enum WidgetAlignment: String, CaseIterable {
    case leading
    case center
    case trailing

    static let `default`: WidgetAlignment = .leading

    var horizontal: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var frame: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}
