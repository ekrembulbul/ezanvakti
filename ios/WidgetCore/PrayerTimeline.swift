import WidgetKit

enum WidgetContent: Equatable {
    case ready(
        next: PrayerSlot,
        day: SnapshotDay,
        phase: DayPhase,
        locationLabel: String,
        isStale: Bool
    )
    /// Widget kurulmuş ama uygulama hiç açılmamış.
    case noData
    /// Payload'ın şeması widget'ın bildiğinden yeni.
    case needsUpdate
}

struct PrayerEntry: TimelineEntry {
    let date: Date
    let content: WidgetContent
}

enum PrayerTimeline {
    /// Timeline'ın ileriyi görme mesafesi. Payload 7 gün taşısa da her
    /// reload'da yalnızca bu kadarı üretilir; gerisi bir sonraki reload'da
    /// tazelenir.
    static let horizonHours = 48

    static let maxEntries = 14

    /// Geri sayım için giriş üretilmez — `Text(date, style: .timer)` sistem
    /// tarafından reload'suz çizilir. Giriş yalnızca **içerik değiştiğinde**,
    /// yani her vakit geçişinde üretilir; vakit geçişi aynı zamanda gün dilimi
    /// sınırıdır, dolayısıyla tek liste hem sıradaki vakti hem gradyanı taşır.
    static func entries(
        for result: Result<WidgetSnapshot, SnapshotLoadError>?,
        now: Date,
        calendar: Calendar
    ) -> [PrayerEntry] {
        guard let result else {
            return [PrayerEntry(date: now, content: .noData)]
        }

        switch result {
        case .failure(.unsupportedSchema):
            return [PrayerEntry(date: now, content: .needsUpdate)]
        case .failure(.malformed):
            return [PrayerEntry(date: now, content: .noData)]
        case .success(let snapshot):
            return entries(for: snapshot, now: now, calendar: calendar)
        }
    }

    private static func entries(
        for snapshot: WidgetSnapshot,
        now: Date,
        calendar: Calendar
    ) -> [PrayerEntry] {
        let slots = NextPrayer.slots(days: snapshot.days, calendar: calendar)
        guard !slots.isEmpty else {
            return [PrayerEntry(date: now, content: .noData)]
        }

        let horizon = now.addingTimeInterval(TimeInterval(horizonHours * 3600))
        let boundaries = slots.map(\.date).filter { $0 > now && $0 <= horizon }
        let moments = ([now] + boundaries).prefix(maxEntries)

        return moments.map { moment in
            PrayerEntry(
                date: moment,
                content: content(
                    for: snapshot, slots: slots, at: moment, calendar: calendar
                )
            )
        }
    }

    private static func content(
        for snapshot: WidgetSnapshot,
        slots: [PrayerSlot],
        at moment: Date,
        calendar: Calendar
    ) -> WidgetContent {
        let key = dateKey(moment, calendar: calendar)
        let today = snapshot.days.first { $0.date == key }

        guard let next = slots.first(where: { $0.date > moment }) else {
            // Pencere tükendi: son bilinen günü bayat olarak göster. Boş kutu
            // bırakmaktansa eski veriyi "güncel değil" damgasıyla göstermek
            // kullanıcıya daha çok şey anlatır.
            return .ready(
                next: slots[slots.count - 1],
                day: snapshot.days[snapshot.days.count - 1],
                phase: DayPhase.fallback,
                locationLabel: snapshot.locationLabel,
                isStale: true
            )
        }

        return .ready(
            next: next,
            day: today ?? snapshot.days[snapshot.days.count - 1],
            phase: DayPhase.resolve(slots: slots, now: moment, calendar: calendar),
            locationLabel: snapshot.locationLabel,
            isStale: today == nil
        )
    }

    /// `SnapshotDay.date` ile karşılaştırmak için `"yyyy-MM-dd"` anahtarı.
    /// `DateFormatter` yerine bileşen kullanılıyor: locale ve takvim
    /// sürprizlerine kapalı.
    private static func dateKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0
        )
    }
}
