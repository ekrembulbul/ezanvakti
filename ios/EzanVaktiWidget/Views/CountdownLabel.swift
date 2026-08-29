import SwiftUI

/// Hibrit geri sayım.
///
/// Ekran açıkken sistemin canlı sayacını kullanırız — saniye akar, biçimine
/// karışamayız. Always-On ekranda aynı metin `"5 hours 51 minutes"` gibi
/// okunmaz bir biçime düşüyor; orada `CountdownText` ile kendimiz çizeriz.
/// Kendi çizimimiz sistemin biçimini taklit eder, yalnızca saniye tire olur.
struct CountdownLabel: View {
    let entry: PrayerEntry
    let target: Date
    let isLuminanceReduced: Bool
    let size: CGFloat
    let color: Color

    var body: some View {
        Group {
            if isLuminanceReduced {
                Text(CountdownText.format(from: entry.date, to: target))
            } else {
                Text(target, style: .timer)
            }
        }
        .font(.system(size: size, weight: .semibold).monospacedDigit())
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}
