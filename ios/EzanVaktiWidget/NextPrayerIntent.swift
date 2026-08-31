import AppIntents
import Foundation

/// "Sıradaki vakit" — Siri ve Spotlight'tan çalışır.
///
/// Salt okuma: App Group'taki snapshot'a bakar, uygulamayı açmaz. Veri yoksa
/// kullanıcıya ne yapması gerektiğini söyler.
struct NextPrayerIntent: AppIntent {
    static var title: LocalizedStringResource = "Sıradaki vakit"
    static var description = IntentDescription(
        "Sıradaki namaz vaktini ve kalan süreyi söyler."
    )

    /// Uygulamayı açmadan cevap verilir; kullanıcı akışı kesilmesin.
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let now = Date()
        let loaded = SnapshotStore.load()
        var labels: SnapshotLabels?
        if case let .success(snapshot)? = loaded { labels = snapshot.labels }

        guard case let .success(snapshot)? = loaded,
            let next = NextPrayer.resolve(
                days: snapshot.days,
                now: now,
                calendar: .current,
                labels: labels)
        else {
            return .result(
                dialog: "\(labels?.openApp ?? "Vakitler için uygulamayı aç")")
        }

        let clock = TimeFormatting.clock(
            next.date, preference: SnapshotStore.timeFormat())
        let remaining = Self.remainingText(from: now, to: next.date, labels: labels)
        let answer = Self.fill(
            labels?.siriAnswer ?? "{prayer} {time}, {remaining} kaldı.",
            values: ["prayer": next.name, "time": clock, "remaining": remaining])
        return .result(dialog: "\(answer)")
    }

    /// "1 saat 12 dakika" gibi; şablonlar uygulamadan gelir, saf tutuluyor
    /// ki sınanabilsin.
    static func remainingText(
        from: Date, to: Date, labels: SnapshotLabels? = nil
    ) -> String {
        let minutes = max(0, Int(to.timeIntervalSince(from) / 60))
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 {
            return fill(
                labels?.durationMinute ?? "{minutes} dakika",
                values: ["minutes": "\(rest)"])
        }
        if rest == 0 {
            return fill(
                labels?.durationHour ?? "{hours} saat",
                values: ["hours": "\(hours)"])
        }
        return fill(
            labels?.durationHourMinute ?? "{hours} saat {minutes} dakika",
            values: ["hours": "\(hours)", "minutes": "\(rest)"])
    }

    /// `{ad}` yer tutucularını doldurur.
    static func fill(_ template: String, values: [String: String]) -> String {
        var result = template
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }
}

/// Siri ve Spotlight'ta görünen kısayol.
struct EzanVaktiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextPrayerIntent(),
            phrases: [
                "\(.applicationName) sıradaki vakit",
                "\(.applicationName) namaz vakti",
            ],
            shortTitle: "Sıradaki vakit",
            systemImageName: "clock"
        )
    }
}
