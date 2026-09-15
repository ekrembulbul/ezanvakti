import SwiftUI

/// Ana ekran ailelerinin ortak zemini.
///
/// Gradyan `GeometryReader` içinde çizilir çünkü yarıçap kısa kenara bağlıdır
/// (`Palette.backgroundGradient(in:)`). Kerahat sürerken zemin bordo tona
/// kayar (`Palette.kerahatBackgroundGradient(in:)`).
struct PhaseBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let phase: DayPhase
    let appearance: WidgetAppearance
    var kerahatActive = false

    var body: some View {
        GeometryReader { geometry in
            let palette = Palette.resolve(appearance, phase: phase, colorScheme: colorScheme)
            if kerahatActive {
                palette.kerahatBackgroundGradient(in: geometry.size)
            } else {
                palette.backgroundGradient(in: geometry.size)
            }
        }
    }
}
