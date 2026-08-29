import Foundation

/// Günün, palet değişimini belirleyen dört dilimi.
///
/// `lib/core/theme/day_phase.dart` portu. İki kural aynen korunur: gece
/// **Akşam'da değil Yatsı'da** başlar, ve sınır anı bir SONRAKİ dilime aittir.
enum DayPhase: Equatable {
    case morning, afternoon, evening, night

    /// Vakit verisi yokken kullanılan dilim; uygulama ikonu da bu ailedendir.
    static let fallback: DayPhase = .evening

    static func resolve(
        slots: [PrayerSlot],
        now: Date,
        calendar: Calendar = .current
    ) -> DayPhase {
        guard
            let fajr = time(of: "İmsak", in: slots, on: now, calendar: calendar),
            let dhuhr = time(of: "Öğle", in: slots, on: now, calendar: calendar),
            let asr = time(of: "İkindi", in: slots, on: now, calendar: calendar),
            let isha = time(of: "Yatsı", in: slots, on: now, calendar: calendar)
        else { return fallback }

        if now < fajr { return .night }
        if now < dhuhr { return .morning }
        if now < asr { return .afternoon }
        if now < isha { return .evening }
        return .night
    }

    /// `now` ile aynı takvim günündeki vakti bulur.
    private static func time(
        of name: String,
        in slots: [PrayerSlot],
        on now: Date,
        calendar: Calendar
    ) -> Date? {
        slots.first {
            $0.name == name && calendar.isDate($0.date, inSameDayAs: now)
        }?.date
    }
}
