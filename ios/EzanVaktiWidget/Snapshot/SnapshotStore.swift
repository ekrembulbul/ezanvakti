import Foundation

/// App Group'taki payload'ı okur. Uygulama hiç açılmadıysa `nil` döner.
enum SnapshotStore {
    static let appGroupId = "group.com.ekrembulbul.ezanvakti"
    static let snapshotKey = "ezanvakti_snapshot"

    static func load() -> Result<WidgetSnapshot, SnapshotLoadError>? {
        guard
            let defaults = UserDefaults(suiteName: appGroupId),
            let raw = defaults.string(forKey: snapshotKey),
            let data = raw.data(using: .utf8)
        else { return nil }

        do {
            return .success(try WidgetSnapshot.decode(data))
        } catch let error as SnapshotLoadError {
            return .failure(error)
        } catch {
            return .failure(.malformed)
        }
    }
}
