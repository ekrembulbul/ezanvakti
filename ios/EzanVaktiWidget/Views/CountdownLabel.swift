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
    /// Cihazda semibold "cok kalin" bulundu; varsayilan regular.
    var weight: Font.Weight = .regular

    var body: some View {
        Group {
            if isLuminanceReduced {
                // SPIKE (0.5.3): sistemin aralik sayaci Always-On'da dakika
                // dakika sayiyor mu? Canli Etkinliklerde sayiyor; widget'ta
                // cihazda dogrulanacak. Sayiyorsa dakikalik kareler tamamen
                // kalkar, CountdownText silinir ve bayatlama sorunu kokten biter.
                // Sayamiyorsa bu satir CountdownText'e geri doner.
                Text(
                    timerInterval: min(entry.date, target)...target,
                    countsDown: true
                )
            } else {
                Text(target, style: .timer)
            }
        }
        .font(.system(size: size, weight: weight).monospacedDigit())
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}
