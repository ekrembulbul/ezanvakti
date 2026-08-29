import Foundation

/// Always-On ekranda kendi çizdiğimiz geri sayım.
///
/// Sistemin `Text(date, style: .timer)` biçimini taklit eder — sıfır dolgusu
/// yok, saat hanesi yalnızca gerekince çıkar — ama saniye yerine tire koyar.
/// Sebep: widget saniyede bir güncellenemiyor, timeline dakika başına giriş
/// üretiyor. Donmuş bir saniye rakamı, tireden daha yanıltıcı olurdu.
enum CountdownText {
    static func format(from: Date, to: Date) -> String {
        let remaining = max(0, Int(to.timeIntervalSince(from)))
        let totalMinutes = remaining / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):--"
        }
        return "\(minutes):--"
    }
}
