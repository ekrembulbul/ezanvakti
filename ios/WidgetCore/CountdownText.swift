import Foundation

/// Always-On ekranda kendi çizdiğimiz geri sayım.
///
/// Sistemin `Text(date, style: .timer)` biçimini taklit eder — sıfır dolgusu
/// yok, saat hanesi yalnızca gerekince çıkar — ama saniye yerine tire koyar.
/// Sebep: widget saniyede bir güncellenemiyor, timeline dakika başına giriş
/// üretiyor. Donmuş bir saniye rakamı, tireden daha yanıltıcı olurdu.
///
/// Metin, girişin **geçerli olduğu pencere boyunca** sistemin göstereceği
/// dakikadır; girişin başladığı andaki değil. Kalan süre tam 4:25:00 iken
/// sonraki 59 saniye "4:24:xx" görüneceği için kare "4:24" der. Aksi halde
/// Always-On canlı sayacın bir dakika önünde kalırdı.
enum CountdownText {
    static func format(from: Date, to: Date) -> String {
        let wholeSeconds = Int(ceil(to.timeIntervalSince(from)))
        let windowSeconds = max(0, wholeSeconds - 1)
        let totalMinutes = windowSeconds / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):--"
        }
        return "\(minutes):--"
    }
}
