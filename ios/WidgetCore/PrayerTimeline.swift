import WidgetKit

enum WidgetContent: Equatable {
    case ready(
        next: PrayerSlot,
        day: SnapshotDay,
        phase: DayPhase,
        locationLabel: String,
        isStale: Bool,
        isTomorrow: Bool
    )
    /// Widget kurulmuş ama uygulama hiç açılmamış.
    case noData
    /// Payload'ın şeması widget'ın bildiğinden yeni.
    case needsUpdate
}

/// Karenin anındaki kerahat durumu; ana ekrandaki `KerahatWarning` ile aynı
/// kural (30 dk önceden uyar, aralık içinde aktif).
enum KerahatStatus: Equatable {
    case approaching(start: Date, end: Date)
    case active(end: Date)

    static let lead: TimeInterval = 30 * 60

    /// Snapshot günlerindeki aralıkları `Date` çiftlerine çevirir; bozuk
    /// biçimli aralık listeden düşer.
    static func intervals(
        days: [SnapshotDay], calendar: Calendar
    ) -> [(start: Date, end: Date)] {
        days.flatMap { day -> [(start: Date, end: Date)] in
            (day.kerahat ?? []).compactMap { interval in
                guard let start = NextPrayer.combine(day: day.date, time: interval.start, calendar: calendar),
                    let end = NextPrayer.combine(day: day.date, time: interval.end, calendar: calendar),
                    end > start
                else { return nil }
                return (start, end)
            }
        }
        .sorted { $0.start < $1.start }
    }

    static func resolve(days: [SnapshotDay], now: Date, calendar: Calendar) -> KerahatStatus? {
        let all = intervals(days: days, calendar: calendar)
        if let active = all.first(where: { $0.start <= now && now < $0.end }) {
            return .active(end: active.end)
        }
        if let soon = all.first(where: { now < $0.start && $0.start.timeIntervalSince(now) <= lead }) {
            return .approaching(start: soon.start, end: soon.end)
        }
        return nil
    }
}

struct PrayerEntry: TimelineEntry {
    let date: Date
    let content: WidgetContent

    /// Karenin anındaki kerahat durumu; yoksa satır çizilmez.
    var kerahat: KerahatStatus? = nil

    /// Kullanıcının "Widget'ı Düzenle" ekranından seçtiği hiza. Timeline saf
    /// kalsın diye burada varsayılanı var; gerçek değeri provider yazıyor.
    var alignment: WidgetAlignment = .default

    /// Uygulamadaki 12/24 saat tercihi; provider App Group'tan okuyup yazar.
    var timeFormat: TimeFormatPreference = .system

    /// Uygulamanın görünüm ayarı; provider App Group'tan okuyup yazar.
    var appearance: WidgetAppearance = .fallback

    /// Uygulamanın dilindeki etiketler; v3 öncesi payload'da nil.
    var labels: SnapshotLabels?
}

enum PrayerTimeline {
    /// Timeline'ın ileriyi görme mesafesi. Payload 7 gün taşısa da her
    /// reload'da yalnızca bu kadarı üretilir; gerisi bir sonraki reload'da
    /// tazelenir.
    static let horizonHours = 48

    /// 48 saatte 12 vakit sınırı + günde 3 kerahat × 3 an (yaklaşma,
    /// başlangıç, bitiş) sığsın; bitişlerin çoğu bir vakit sınırıyla çakışır.
    static let maxEntries = 24

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
        let slots = NextPrayer.slots(
            days: snapshot.days, calendar: calendar, labels: snapshot.labels)
        guard !slots.isEmpty else {
            return [PrayerEntry(date: now, content: .noData)]
        }

        // Geri sayımı sistem çiziyor (`Text(timerInterval:)`) — Always-On'da
        // da; 0.5.4'te cihazda ölçüldü. Kare yalnızca **içerik değiştiğinde**,
        // yani her vakit geçişinde gerekir. Vakit geçişi aynı zamanda gün
        // dilimi sınırıdır, tek liste hem sıradaki vakti hem gradyanı taşır.
        // Dakikalık kare üretimi (0.5.1–0.5.3) buna gerek bırakmıyordu.
        let horizon = now.addingTimeInterval(TimeInterval(horizonHours * 3600))
        let boundaries = slots.map(\.date).filter { $0 > now && $0 <= horizon }
        // Kerahat satırı da içeriktir: yaklaşma anı, başlangıç ve bitiş birer
        // kare ister. Bitiş çoğunlukla bir vakit sınırıyla çakışır; küme
        // tekrarı eler.
        let kerahatMoments = KerahatStatus.intervals(days: snapshot.days, calendar: calendar)
            .flatMap { [$0.start.addingTimeInterval(-KerahatStatus.lead), $0.start, $0.end] }
            .filter { $0 > now && $0 <= horizon }
        let moments = Array(Set([now] + boundaries + kerahatMoments)).sorted().prefix(maxEntries)

        return moments.map { moment in
            PrayerEntry(
                date: moment,
                content: content(
                    for: snapshot, slots: slots, at: moment, calendar: calendar
                ),
                kerahat: KerahatStatus.resolve(days: snapshot.days, now: moment, calendar: calendar),
                labels: snapshot.labels
            )
        }
    }

    private static func content(
        for snapshot: WidgetSnapshot,
        slots: [PrayerSlot],
        at moment: Date,
        calendar: Calendar
    ) -> WidgetContent {
        guard let next = slots.first(where: { $0.date > moment }) else {
            // Pencere tükendi: son bilinen günü bayat olarak göster. Boş kutu
            // bırakmaktansa eski veriyi "güncel değil" damgasıyla göstermek
            // kullanıcıya daha çok şey anlatır.
            return .ready(
                next: slots[slots.count - 1],
                day: snapshot.days[snapshot.days.count - 1],
                phase: DayPhase.fallback,
                locationLabel: snapshot.locationLabel,
                isStale: true,
                isTomorrow: false
            )
        }

        // Liste, sıradaki vaktin gününü gösterir. `moment`'in gününü
        // gösterseydi Yatsı'dan sonra sol sütun yarını, sağ sütun bugünü
        // gösterirdi ve vurgulanacak satır listede hiç bulunmazdı.
        let nextDayKey = dateKey(next.date, calendar: calendar)
        let day = snapshot.days.first { $0.date == nextDayKey }

        return .ready(
            next: next,
            day: day ?? snapshot.days[snapshot.days.count - 1],
            phase: DayPhase.resolve(slots: slots, now: moment, calendar: calendar),
            locationLabel: snapshot.locationLabel,
            isStale: day == nil,
            isTomorrow: nextDayKey != dateKey(moment, calendar: calendar)
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
