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

/// Günün yaklaşık kerahat aralığı (v4); `"HH:mm"`, başlangıç dahil bitiş hariç.
/// Uygulama hesaplar (`KerahatTimes`), widget sabit tutmaz.
struct SnapshotInterval: Decodable, Equatable {
    let start: String
    let end: String
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

    /// Kerahat kartı/çipi (v4): tek kelime, yanına sistem sayacı gelir.
    let kerahat: String?

    /// Şerit yaklaşırken (2026-09-21): tek kelime, sayaç başlangıca sayar.
    /// Şema sürümü aynı; eski uygulamanın payload'ında yok.
    let kerahatSoon: String?

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

/// Cetvel parçasının anlamı; Dart `RulerSegmentKind` ile aynı adlar.
enum RulerSegmentKind: String, Decodable, Equatable {
    /// İmsak → Akşam.
    case day
    /// Akşam → ertesi İmsak; Yatsı bunun içindedir.
    case night
    /// Yaklaşık kerahat aralığı.
    case kerahat
}

/// Cetvelin oran uzayındaki (0..1) bir parçası. `gapBefore`/`gapAfter`
/// parçanın o ucunun bir vakit sınırı olduğunu söyler; orada boşluk bırakılır.
struct SnapshotRulerSegment: Decodable, Equatable {
    let start: Double
    let end: Double
    let kind: RulerSegmentKind
    let gapBefore: Bool
    let gapAfter: Bool
}

/// Günün cetveli (2026-10-08): ana ekran cetvelinin parçaları ve altı vaktin
/// çentik oranları. Uygulama hesaplar, widget yalnız çizer.
struct SnapshotRuler: Decodable, Equatable {
    let segments: [SnapshotRulerSegment]
    let marks: [Double]
}

struct SnapshotDay: Decodable, Equatable {
    /// `"yyyy-MM-dd"`. Offset taşımaz; cihaz-yerel wall-clock olarak yorumlanır.
    let date: String

    /// Uygulamanın hesapladığı hicri tarih. v1 payload'da yoktur.
    let hijri: String?

    let times: SnapshotTimes

    /// Günün kerahat aralıkları; v4 öncesi payload'da yoktur.
    var kerahat: [SnapshotInterval]? = nil

    /// Uygulamanın dilinde gün adı (`"Perşembe"`), tarih (`"8 Ekim"`) ve
    /// yılsız hicri tarih (`"27 Rebiülahir"`). Şema sürümü aynı (4); eski
    /// uygulamanın payload'ında yok, `DayLabel` `tr_TR` biçimine düşer.
    var weekday: String? = nil
    var dateLabel: String? = nil
    var hijriShort: String? = nil

    /// Orta boydaki cetvel; yoksa cetvel alanı çizilmez.
    var ruler: SnapshotRuler? = nil
}

extension SnapshotDay {
    private enum CodingKeys: String, CodingKey {
        case date, hijri, times, kerahat, weekday, dateLabel, hijriShort, ruler
    }

    /// Eski alanlar önceki gibi katı çözülür. Yeni alanlar (tarih metinleri,
    /// cetvel) bozuksa yalnız kendileri düşer: süs için eklenen bir alan
    /// yüzünden bütün payload'ı "bozuk" sayıp widget'ı "uygulamayı aç"a
    /// düşürmek, cetvelsiz çizmekten kötüdür.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        hijri = try container.decodeIfPresent(String.self, forKey: .hijri)
        times = try container.decode(SnapshotTimes.self, forKey: .times)
        kerahat = try container.decodeIfPresent([SnapshotInterval].self, forKey: .kerahat)
        weekday = try? container.decodeIfPresent(String.self, forKey: .weekday)
        dateLabel = try? container.decodeIfPresent(String.self, forKey: .dateLabel)
        hijriShort = try? container.decodeIfPresent(String.self, forKey: .hijriShort)
        ruler = try? container.decodeIfPresent(SnapshotRuler.self, forKey: .ruler)
    }
}

/// Uygulamanın App Group'a yazdığı payload.
///
/// Dart tarafındaki karşılığı `lib/features/home_widget/domain/widget_snapshot.dart`.
struct WidgetSnapshot: Decodable, Equatable {
    /// v1 hâlâ kabul edilir: güncelleme anında App Group'ta eski payload
    /// duruyor olabilir ve onu reddetmek, uygulama zaten güncelken
    /// "uygulamayı güncelleyin" göstermek olurdu. Bilinmeyen sürüm reddedilir;
    /// çöp çizmek yerine kullanıcıya güncelleme mesajı gösterilir.
    static let supportedSchemaVersions: Set<Int> = [1, 2, 3, 4]

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

// MARK: - Cetvel geometrisi
//
// Ayrı dosya yerine burada: WidgetCore dosyaları proje dosyasında hedef hedef
// listeli; bu dosya hem widget eklentisine hem test hedefine zaten giriyor.

/// Cetvelin çizilecek bir parçası: yatay aralık (pt) ve uçların yuvarlaklığı.
struct RulerSpan: Equatable {
    let x0: Double
    let x1: Double
    let kind: RulerSegmentKind
    /// Gün başı ya da vakit sınırı: uç yuvarlak. Kerahat sınırları düz
    /// birleşir (ana ekran cetveliyle aynı).
    let roundLeading: Bool
    let roundTrailing: Bool
}

/// Orta boy widget cetvelinin saf geometrisi (SwiftUI yok; XCTest'te sınanır).
///
/// Ana ekran cetvelinin (`day_ruler.dart`) ve Android bitmap'inin
/// (`RulerBitmap.kt`) aynısı: parçalar payload'dan gelir, vakit sınırlarında
/// 3 pt gerçek boşluk bırakılır (zemin oradan görünür), çentikler yatağın
/// altında, şu an noktası kenarlarda kırpılır ki taşmasın.
enum RulerGeometry {
    /// Vakit sınırındaki boşluk; iki parça yarısını verir.
    static let markGap: Double = 3
    static let trackHeight: Double = 5
    static let dotSize: Double = 14
    static let dotInnerSize: Double = 8
    static let tickWidth: Double = 2
    static let tickHeight: Double = 6
    /// Yatak ile çentik arası.
    static let tickGap: Double = 2
    /// Yatağın dikey merkezi. iOS'ta noktanın üstüne saat etiketi konmaz:
    /// WidgetKit'te canlı akan saat yok, kare anının saati 15 dk'ya kadar
    /// geride kalırdı (Android'de `TextClock` canlı).
    static let trackCenter: Double = dotSize / 2
    static let trackTop: Double = trackCenter - trackHeight / 2
    static let tickTop: Double = trackTop + trackHeight + tickGap
    /// Toplam yükseklik; nokta yokken de aynı, yerleşim zıplamasın.
    static let height: Double = tickTop + tickHeight

    /// Parçaların çizim aralıkları. Bozuk (sonlu olmayan, ters) parça düşer;
    /// oranlar 0..1'e kırpılır; boşluklar düşünce genişliği kalmayan parça
    /// çizilmez.
    static func spans(segments: [SnapshotRulerSegment], width: Double) -> [RulerSpan] {
        guard width > 0 else { return [] }
        return segments.compactMap { segment in
            guard segment.start.isFinite, segment.end.isFinite else { return nil }
            let start = min(max(segment.start, 0), 1)
            let end = min(max(segment.end, 0), 1)
            guard end > start else { return nil }
            let x0 = start * width + (segment.gapBefore ? markGap / 2 : 0)
            let x1 = end * width - (segment.gapAfter ? markGap / 2 : 0)
            guard x1 > x0 else { return nil }
            return RulerSpan(
                x0: x0, x1: x1, kind: segment.kind,
                roundLeading: start <= 0 || segment.gapBefore,
                roundTrailing: end >= 1 || segment.gapAfter)
        }
    }

    /// Çentiklerin sol kenarı: `(genişlik − çentik) × oran`, uçtaki çentik de
    /// cetvelin içinde kalır. Bozuk oran düşer.
    static func markXs(marks: [Double], width: Double) -> [Double] {
        guard width > 0 else { return [] }
        return marks.compactMap { mark in
            guard mark.isFinite, mark >= 0, mark <= 1 else { return nil }
            return (width - tickWidth) * mark
        }
    }

    /// Noktanın yatay merkezi; yarıçap kadar içeride kırpılır.
    static func dotCenterX(fraction: Double, width: Double) -> Double {
        clampedCenter(width * fraction, itemWidth: dotSize, width: width)
    }


    /// `now`'ın gösterilen takvim gününün (00:00–24:00) içindeki oranı.
    /// Gün bugün değilse (Yatsı'dan sonra liste yarını gösterir) nil: nokta
    /// çizilmez. Gün uzunluğu takvimden; DST günü 23 ya da 25 saat olabilir.
    static func dayFraction(now: Date, day: String, calendar: Calendar) -> Double? {
        guard let start = NextPrayer.combine(day: day, time: "00:00", calendar: calendar),
            let end = calendar.date(byAdding: .day, value: 1, to: start),
            end > start, now >= start, now < end
        else { return nil }
        return now.timeIntervalSince(start) / end.timeIntervalSince(start)
    }

    private static func clampedCenter(_ x: Double, itemWidth: Double, width: Double) -> Double {
        let half = itemWidth / 2
        guard x.isFinite else { return half }
        return min(max(x, half), max(width - half, half))
    }
}
