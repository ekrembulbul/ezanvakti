import Foundation

struct PrayerSlot: Equatable {
    /// Dile bağlı **olmayan** kimlik (`fajr`, `dhuhr`…). Palet ve sıralama
    /// buna bakar; ad çevrildiğinde mantık bozulmasın diye ayrı tutuluyor.
    let key: PrayerKey

    /// Kullanıcıya gösterilen ad. Snapshot etiket taşıyorsa uygulamanın
    /// dilinde, taşımıyorsa Türkçe varsayılan.
    let name: String

    let date: Date
}

/// Vakitlerin dile bağlı olmayan kimlikleri.
enum PrayerKey: String, CaseIterable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha

    /// Etiket gelmediğinde kullanılan Türkçe adlar (uygulamanın kaynak dili).
    var defaultName: String {
        switch self {
        case .fajr: return "İmsak"
        case .sunrise: return "Güneş"
        case .dhuhr: return "Öğle"
        case .asr: return "İkindi"
        case .maghrib: return "Akşam"
        case .isha: return "Yatsı"
        }
    }
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
    static func slots(
        days: [SnapshotDay],
        calendar: Calendar,
        labels: SnapshotLabels? = nil
    ) -> [PrayerSlot] {
        days.flatMap { day -> [PrayerSlot] in
            let times: [(PrayerKey, String)] = [
                (.fajr, day.times.fajr),
                (.sunrise, day.times.sunrise),
                (.dhuhr, day.times.dhuhr),
                (.asr, day.times.asr),
                (.maghrib, day.times.maghrib),
                (.isha, day.times.isha),
            ]
            return times.compactMap { key, time in
                guard let date = combine(day: day.date, time: time, calendar: calendar)
                else { return nil }
                return PrayerSlot(
                    key: key,
                    name: labels?.name(for: key) ?? key.defaultName,
                    date: date)
            }
        }
        .sorted { $0.date < $1.date }
    }

    static func resolve(
        days: [SnapshotDay],
        now: Date,
        calendar: Calendar,
        labels: SnapshotLabels? = nil
    ) -> PrayerSlot? {
        slots(days: days, calendar: calendar, labels: labels).first { $0.date > now }
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
