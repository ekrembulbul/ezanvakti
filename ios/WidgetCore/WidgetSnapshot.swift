import Foundation

enum SnapshotLoadError: Error, Equatable {
    case unsupportedSchema
    case malformed
}

struct SnapshotTimes: Decodable, Equatable {
    let fajr: String
    let sunrise: String
    let dhuhr: String
    let asr: String
    let maghrib: String
    let isha: String
}

struct SnapshotDay: Decodable, Equatable {
    /// `"yyyy-MM-dd"`. Offset taşımaz; cihaz-yerel wall-clock olarak yorumlanır.
    let date: String

    /// Uygulamanın hesapladığı hicri tarih. v1 payload'da yoktur.
    let hijri: String?

    let times: SnapshotTimes
}

/// Uygulamanın App Group'a yazdığı payload.
///
/// Dart tarafındaki karşılığı `lib/features/home_widget/domain/widget_snapshot.dart`.
struct WidgetSnapshot: Decodable, Equatable {
    /// v1 hâlâ kabul edilir: güncelleme anında App Group'ta eski payload
    /// duruyor olabilir ve onu reddetmek, uygulama zaten güncelken
    /// "uygulamayı güncelleyin" göstermek olurdu. Bilinmeyen sürüm reddedilir;
    /// çöp çizmek yerine kullanıcıya güncelleme mesajı gösterilir.
    static let supportedSchemaVersions: Set<Int> = [1, 2]

    let schemaVersion: Int
    let locationLabel: String
    let days: [SnapshotDay]

    static func decode(_ json: Data) throws -> WidgetSnapshot {
        let snapshot: WidgetSnapshot
        do {
            snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: json)
        } catch {
            throw SnapshotLoadError.malformed
        }

        guard supportedSchemaVersions.contains(snapshot.schemaVersion) else {
            throw SnapshotLoadError.unsupportedSchema
        }
        return snapshot
    }
}
