import Foundation

/// Bir alarmın zincir kayıtlarını seçer: nöbetçi (`<id>#w`) ve merdiven
/// basamakları (`<id>#ladder<n>`). Birincil `<id>` dahil **değildir**.
///
/// Saf tutuluyor ki XCTest'te sınanabilsin; `AlarmKitHandler.endMission`
/// bunu defterdeki anahtarlara uygular.
enum MissionChainKeys {
    static func select(alarmId: String, from keys: [String]) -> [String] {
        let prefix = "\(alarmId)#"
        return keys.filter { $0.hasPrefix(prefix) }
    }
}
