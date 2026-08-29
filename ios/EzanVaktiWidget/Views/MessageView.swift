import SwiftUI

/// Veri olmadığında çizilen görünüm. Boş kutu bırakmıyoruz: kullanıcı ne
/// yapması gerektiğini okuyabilmeli.
struct MessageView: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String
    let phase: DayPhase

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Palette.forPhase(phase, colorScheme: colorScheme).textSecondary)
            .multilineTextAlignment(.center)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
