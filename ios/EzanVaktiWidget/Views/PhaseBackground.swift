import SwiftUI

/// Ana ekran ailelerinin ortak zemini.
///
/// Gradyan `GeometryReader` içinde çizilir çünkü yarıçap kısa kenara bağlıdır
/// (`Palette.backgroundGradient(in:)`). Kerahat sürerken zemin bordoya kayar
/// (`Palette.duringKerahat(active:)`, 2026-10-09); yaklaşırken değişmez,
/// orada kart/band yeter.
struct PhaseBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let phase: DayPhase
    let appearance: WidgetAppearance
    let isKerahatActive: Bool

    var body: some View {
        GeometryReader { geometry in
            Palette.resolve(appearance, phase: phase, colorScheme: colorScheme)
                .duringKerahat(active: isKerahatActive)
                .backgroundGradient(in: geometry.size)
        }
    }
}
