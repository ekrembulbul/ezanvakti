import SwiftUI

/// Orta boy widget'ın gün cetveli (spec K8): ana ekran cetvelinin aynısı.
/// Gündüz vurgu renginde, gece soluk, kerahat bordo; vakit sınırlarında gerçek
/// boşluk (zemin oradan görünür), altında çentikler, şu an noktası ve üstünde
/// saat. Parçalar payload'dan gelir (`SnapshotRuler`); geometri saf
/// `RulerGeometry`'de.
///
/// Nokta ve saat yalnız gösterilen gün bugünse çizilir; yükseklik iki durumda
/// da aynı. Saat etiketi karenin anıdır (`entry.date`): WidgetKit'te canlı
/// akan bir saat yok, nokta da karede sabit.
struct RulerView: View {
    let ruler: SnapshotRuler
    let palette: Palette
    /// Gösterilen günün içindeki oran; gün bugün değilse nil.
    let nowFraction: Double?

    var body: some View {
        GeometryReader { geometry in
            let width = Double(geometry.size.width)
            ZStack(alignment: .topLeading) {
                ForEach(
                    Array(RulerGeometry.spans(segments: ruler.segments, width: width).enumerated()),
                    id: \.offset
                ) { _, span in
                    segment(span)
                }
                ForEach(
                    Array(RulerGeometry.markXs(marks: ruler.marks, width: width).enumerated()),
                    id: \.offset
                ) { _, x in
                    RoundedRectangle(cornerRadius: RulerGeometry.tickWidth / 2)
                        .fill(palette.textSecondary.opacity(0.7))
                        .frame(width: RulerGeometry.tickWidth, height: RulerGeometry.tickHeight)
                        .offset(x: x, y: RulerGeometry.tickTop)
                }
                if let nowFraction {
                    marker(fraction: nowFraction, width: width)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .frame(height: RulerGeometry.height)
        // Gün soldan sağa akar; ana ekran cetveli de Arapçada çevrilmiyor.
        .environment(\.layoutDirection, .leftToRight)
    }

    private func color(_ kind: RulerSegmentKind) -> Color {
        switch kind {
        case .day: return palette.accent
        case .night: return palette.textSecondary.opacity(0.4)
        case .kerahat: return palette.kerahatLine
        }
    }

    /// Yalnız gün uçlarında ve vakit boşluklarında yuvarlak köşe; kerahat
    /// sınırları düz birleşir.
    private func segment(_ span: RulerSpan) -> some View {
        let radius = RulerGeometry.trackHeight / 2
        let leading = span.roundLeading ? radius : 0
        let trailing = span.roundTrailing ? radius : 0
        return UnevenRoundedRectangle(
            topLeadingRadius: leading,
            bottomLeadingRadius: leading,
            bottomTrailingRadius: trailing,
            topTrailingRadius: trailing,
            style: .circular
        )
        .fill(color(span.kind))
        .frame(width: span.x1 - span.x0, height: RulerGeometry.trackHeight)
        .offset(x: span.x0, y: RulerGeometry.trackTop)
    }

    /// Nokta: dış halka zeminin orta tonunda (yatağın üstünde ayrışsın), içi
    /// vurgu. Saat etiketi yok (bkz. `RulerGeometry.trackCenter`).
    @ViewBuilder
    private func marker(fraction: Double, width: Double) -> some View {
        let dotX = RulerGeometry.dotCenterX(fraction: fraction, width: width)
        Circle()
            .fill(palette.backgroundStops[1])
            .frame(width: RulerGeometry.dotSize, height: RulerGeometry.dotSize)
            .overlay {
                Circle()
                    .fill(palette.accent)
                    .frame(width: RulerGeometry.dotInnerSize, height: RulerGeometry.dotInnerSize)
            }
            .offset(
                x: dotX - RulerGeometry.dotSize / 2,
                y: RulerGeometry.trackCenter - RulerGeometry.dotSize / 2)
    }
}
