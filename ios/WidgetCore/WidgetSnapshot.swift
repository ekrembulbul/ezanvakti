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

/// Uygulamanın kendi dilinde ürettiği etiketler (v3+).
///
/// Widget'ta ayrı bir çeviri dosyası tutmak yerine metinler uygulamadan
/// geliyor: kullanıcı uygulama içinde dil seçtiğinde widget da o dile geçer,
/// cihaz dili farklı olsa bile.
struct SnapshotLabels: Decodable, Equatable {
    let fajr: String?
    let sunrise: String?
    let dhuhr: String?
    let asr: String?
    let maghrib: String?
    let isha: String?
    let tomorrow: String?
    let stale: String?
    let openApp: String?
    let updateApp: String?

    /// Siri cevabı: `{prayer}`, `{time}` ve `{remaining}` yer tutucuları.
    let siriAnswer: String?

    /// Kalan süre: `{hours}` ve `{minutes}` yer tutucuları.
    let durationHourMinute: String?
    let durationHour: String?
    let durationMinute: String?

    func name(for key: PrayerKey) -> String {
        let value: String?
        switch key {
        case .fajr: value = fajr
        case .sunrise: value = sunrise
        case .dhuhr: value = dhuhr
        case .asr: value = asr
        case .maghrib: value = maghrib
        case .isha: value = isha
        }
        return value ?? key.defaultName
    }
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
    static let supportedSchemaVersions: Set<Int> = [1, 2, 3]

    let schemaVersion: Int
    let locationLabel: String
    let days: [SnapshotDay]

    /// v3'te gelir; eski payload'da yok ve Türkçe varsayılanlar kullanılır.
    let labels: SnapshotLabels?

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
