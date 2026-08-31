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
        // Ada değil **anahtara** bakılıyor: vakit adları kullanıcının diline
        // göre değişiyor, palet hesabı değişmemeli.
        guard
            let fajr = time(of: .fajr, in: slots, on: now, calendar: calendar),
            let dhuhr = time(of: .dhuhr, in: slots, on: now, calendar: calendar),
            let asr = time(of: .asr, in: slots, on: now, calendar: calendar),
            let isha = time(of: .isha, in: slots, on: now, calendar: calendar)
        else { return fallback }

        if now < fajr { return .night }
        if now < dhuhr { return .morning }
        if now < asr { return .afternoon }
        if now < isha { return .evening }
        return .night
    }

    /// `now` ile aynı takvim günündeki vakti bulur.
    private static func time(
        of key: PrayerKey,
        in slots: [PrayerSlot],
        on now: Date,
        calendar: Calendar
    ) -> Date? {
        slots.first {
            $0.key == key && calendar.isDate($0.date, inSameDayAs: now)
        }?.date
    }
}
