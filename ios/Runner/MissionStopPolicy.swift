import Foundation

enum StopAction: Equatable {
    /// Görevsiz alarm: durdurma kesin, nöbetçi yok. Olay yine kuyruğa yazılır
    /// ki uygulama açılınca ara ekran erteleme sunabilsin.
    case ignore
    case rearm
    case stopChain
}

/// Alarm durdurulunca nöbetçi kurulsun mu? Saf; `handleStop` bunu uygular.
enum MissionStopPolicy {
    static func action(
        gated: Bool, rearmCount: Int, maxRearms: Int,
        nowMillis: Double, chainDeadlineMillis: Double
    ) -> StopAction {
        guard gated else { return .ignore }
        guard rearmCount < maxRearms, nowMillis < chainDeadlineMillis else {
            return .stopChain
        }
        return .rearm
    }
}
