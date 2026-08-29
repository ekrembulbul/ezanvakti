import Foundation

struct PrayerSlot: Equatable {
    /// Uygulamadaki adla aynı (`prayer_utils.dart:8`).
    let name: String
    let date: Date
}

enum NextPrayer {
    /// Payload'daki `"HH:mm"` değerlerini cihaz-yerel `Date`e çevirir.
    ///
    /// Takvim çağırandan gelir; böylece test sabit bir takvimle koşar,
    /// üretimde `Calendar.current` kullanılır.
    ///
    /// Bozuk biçimli bir saat çökme değil, o vaktin listeden düşmesi demektir:
    /// tek bozuk alan yüzünden widget'ın tamamen kararması, kalan beş vakti
    /// göstermesinden kötüdür.
    static func slots(days: [SnapshotDay], calendar: Calendar) -> [PrayerSlot] {
        days.flatMap { day -> [PrayerSlot] in
            let named: [(String, String)] = [
                ("İmsak", day.times.fajr),
                ("Güneş", day.times.sunrise),
                ("Öğle", day.times.dhuhr),
                ("İkindi", day.times.asr),
                ("Akşam", day.times.maghrib),
                ("Yatsı", day.times.isha),
            ]
            return named.compactMap { name, time in
                guard let date = combine(day: day.date, time: time, calendar: calendar)
                else { return nil }
                return PrayerSlot(name: name, date: date)
            }
        }
        .sorted { $0.date < $1.date }
    }

    static func resolve(days: [SnapshotDay], now: Date, calendar: Calendar) -> PrayerSlot? {
        slots(days: days, calendar: calendar).first { $0.date > now }
    }

    private static func combine(day: String, time: String, calendar: Calendar) -> Date? {
        let dayParts = day.split(separator: "-").compactMap { Int($0) }
        let timeParts = time.split(separator: ":").compactMap { Int($0) }
        guard dayParts.count == 3, timeParts.count == 2 else { return nil }

        return calendar.date(from: DateComponents(
            year: dayParts[0], month: dayParts[1], day: dayParts[2],
            hour: timeParts[0], minute: timeParts[1]
        ))
    }
}
