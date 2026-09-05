import Foundation

/// App Group'taki payload'ı okur. Uygulama hiç açılmadıysa `nil` döner.
enum SnapshotStore {
    static let appGroupId = "group.com.ekrembulbul.ezanvakti"
    static let snapshotKey = "ezanvakti_snapshot"
    static let timeFormatKey = "ezanvakti_time_format"
    static let appearanceKey = "ezanvakti_appearance"

    /// Kullanıcının 12/24 saat tercihi. Snapshot şemasının parçası **değil**:
    /// ayrı bir anahtar, çünkü tercih değiştiğinde vakit verisini yeniden
    /// yazmak gerekmiyor.
    static func timeFormat() -> TimeFormatPreference {
        let defaults = UserDefaults(suiteName: appGroupId)
        return TimeFormatPreference.from(defaults?.string(forKey: timeFormatKey))
    }

    /// Uygulamanın görünüm ayarı (tema, vakte göre renk, sabit palet). Ayrı
    /// anahtar: tema değişince vakit verisini yeniden yazmak gerekmiyor.
    /// Anahtar yoksa ya da bozuksa kurulum varsayılanı.
    static func appearance() -> WidgetAppearance {
        let defaults = UserDefaults(suiteName: appGroupId)
        return WidgetAppearance.decode(defaults?.string(forKey: appearanceKey))
    }

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
