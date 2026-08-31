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
        guard case let .success(snapshot)? = SnapshotStore.load(),
            let next = NextPrayer.resolve(
                days: snapshot.days, now: now, calendar: .current)
        else {
            return .result(
                dialog: "Vakit bilgisi yok. Ezan Vakti'ni bir kez açman yeterli."
            )
        }

        let clock = TimeFormatting.clock(
            next.date, preference: SnapshotStore.timeFormat())
        let remaining = Self.remainingText(from: now, to: next.date)
        return .result(dialog: "\(next.name) \(clock), \(remaining) kaldı.")
    }

    /// "1 saat 12 dakika" gibi; saf tutuluyor ki sınanabilsin.
    static func remainingText(from: Date, to: Date) -> String {
        let minutes = max(0, Int(to.timeIntervalSince(from) / 60))
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest) dakika" }
        if rest == 0 { return "\(hours) saat" }
        return "\(hours) saat \(rest) dakika"
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
