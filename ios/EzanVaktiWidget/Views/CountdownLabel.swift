import SwiftUI

/// Geri sayım.
///
/// Sistemin aralık sayacı: saniye canlı akar, Always-On'da dakika dakika
/// sayar (0.5.4'te cihazda ölçüldü), vakit geçince 0:00'da durur. Hangi
/// karenin ekranda olduğuna bağlı değil — bayatlama diye bir şey kalmadı.
/// `Text(date, style: .timer)` Always-On'da "5 hours 51 minutes" gibi okunmaz
/// bir biçime düşüyordu; kendi çizdiğimiz dakikalık kareler ise 15 dakikaya
/// kadar bayatlıyordu.
struct CountdownLabel: View {
    let entry: PrayerEntry
    let target: Date
    let size: CGFloat
    let color: Color
    var weight: Font.Weight = .regular

    var body: some View {
        Text(timerInterval: min(entry.date, target)...target, countsDown: true)
            .font(.system(size: size, weight: weight).monospacedDigit())
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}
