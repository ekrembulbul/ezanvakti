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

struct PrayerEntry: TimelineEntry {
    let date: Date
    let content: WidgetContent

    /// Kullanıcının "Widget'ı Düzenle" ekranından seçtiği hiza. Timeline saf
    /// kalsın diye burada varsayılanı var; gerçek değeri provider yazıyor.
    var alignment: WidgetAlignment = .default
}

enum PrayerTimeline {
    /// Timeline'ın ileriyi görme mesafesi, dakika cinsinden.
    ///
    /// Always-On ekranda geri sayımı biz çiziyoruz (`CountdownText`) ve widget
    /// görünümleri önceden hazırlandığı için sayının dakikada bir değişmesinin
    /// tek yolu dakika başına giriş üretmek (bkz. `moments`). Girişler
    /// yenileme bütçesi harcamaz; harcayan, timeline tükendiğinde istenen
    /// yenilemedir. İki saatlik pencere günde ~12 yenileme demek.
    static let windowMinutes = 120

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

        return moments(from: now, calendar: calendar).map { moment in
            PrayerEntry(
                date: moment,
                content: content(
                    for: snapshot, slots: slots, at: moment, calendar: calendar
                )
            )
        }
    }

    /// `now`, ardından pencere sonuna kadar her **tam dakika** (:00).
    ///
    /// Vakitler tam dakikada olduğu için canlı sayaç dakika hanesini her
    /// :00'da değiştiriyor; kareler de oraya hizalı olmalı. `now + k dakika`
    /// olsaydı kare, canlı sayacın bir dakika önünde kalırdı ve kilit ekranı
    /// açıkken 4:25:33 gösteren widget Always-On'da 4:26 derdi.
    private static func moments(from now: Date, calendar: Calendar) -> [Date] {
        let end = now.addingTimeInterval(TimeInterval(windowMinutes * 60))
        var result = [now]

        var next = ceilToMinute(now, calendar: calendar)
        if next == now { next = next.addingTimeInterval(60) }
        while next <= end {
            result.append(next)
            next = next.addingTimeInterval(60)
        }
        return result
    }

    private static func ceilToMinute(_ date: Date, calendar: Calendar) -> Date {
        let floor = calendar.dateInterval(of: .minute, for: date)?.start ?? date
        return floor == date ? date : floor.addingTimeInterval(60)
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
