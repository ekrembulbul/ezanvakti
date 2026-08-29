import SwiftUI

/// Ana ekran ailelerinin ortak zemini.
///
/// Gradyan `GeometryReader` içinde çizilir çünkü yarıçap kısa kenara bağlıdır
/// (`Palette.backgroundGradient(in:)`).
struct PhaseBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let phase: DayPhase

    var body: some View {
        GeometryReader { geometry in
            Palette.forPhase(phase, colorScheme: colorScheme)
                .backgroundGradient(in: geometry.size)
        }
    }
}
