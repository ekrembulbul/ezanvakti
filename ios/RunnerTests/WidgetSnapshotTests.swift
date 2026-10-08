import XCTest

final class WidgetSnapshotTests: XCTestCase {
    private func jsonV2(schemaVersion: Int = 2) -> Data {
        """
        {
          "schemaVersion": \(schemaVersion),
          "locationLabel": "Ankara",
          "generatedAt": "2026-08-29T23:03:00",
          "days": [
            { "date": "2026-08-29",
              "hijri": "13 Rebiülevvel 1448",
              "times": { "fajr": "04:37", "sunrise": "06:06", "dhuhr": "12:55",
                         "asr": "16:36", "maghrib": "19:32", "isha": "20:55" } }
          ]
        }
        """.data(using: .utf8)!
    }

    private var jsonV1: Data {
        """
        {
          "schemaVersion": 1,
          "locationLabel": "Ankara",
          "generatedAt": "2026-08-29T23:03:00",
          "days": [
            { "date": "2026-08-29",
              "times": { "fajr": "04:37", "sunrise": "06:06", "dhuhr": "12:55",
                         "asr": "16:36", "maghrib": "19:32", "isha": "20:55" } }
          ]
        }
        """.data(using: .utf8)!
    }

    func testDecodesV2WithHijri() throws {
        let snapshot = try WidgetSnapshot.decode(jsonV2())
        XCTAssertEqual(snapshot.locationLabel, "Ankara")
        XCTAssertEqual(snapshot.days[0].hijri, "13 Rebiülevvel 1448")
        XCTAssertEqual(snapshot.days[0].times.asr, "16:36")
    }

    /// Guncelleme aninda App Group'ta hala v1 payload duruyor olabilir.
    /// Reddetseydik kullaniciya uygulama zaten guncelken "uygulamayi
    /// guncelleyin" gosterirdik.
    func testAcceptsV1WithoutHijri() throws {
        let snapshot = try WidgetSnapshot.decode(jsonV1)
        XCTAssertNil(snapshot.days[0].hijri)
        XCTAssertEqual(snapshot.days[0].times.fajr, "04:37")
    }

    func testRejectsUnknownSchemaVersion() {
        XCTAssertThrowsError(try WidgetSnapshot.decode(jsonV2(schemaVersion: 99))) { error in
            XCTAssertEqual(error as? SnapshotLoadError, .unsupportedSchema)
        }
    }

    func testRejectsMalformedPayload() {
        let broken = "{ not json".data(using: .utf8)!
        XCTAssertThrowsError(try WidgetSnapshot.decode(broken)) { error in
            XCTAssertEqual(error as? SnapshotLoadError, .malformed)
        }
    }

    private var jsonV4: Data {
        """
        {
          "schemaVersion": 4,
          "locationLabel": "Ankara",
          "generatedAt": "2026-08-29T23:03:00",
          "days": [
            { "date": "2026-08-29",
              "hijri": "13 Rebiülevvel 1448",
              "times": { "fajr": "04:37", "sunrise": "06:06", "dhuhr": "12:55",
                         "asr": "16:36", "maghrib": "19:32", "isha": "20:55" },
              "kerahat": [ { "start": "06:06", "end": "06:51" },
                           { "start": "12:45", "end": "12:55" },
                           { "start": "18:47", "end": "19:32" } ] }
          ],
          "labels": { "kerahat": "Kerahat", "kerahatSoon": "Kerahate" }
        }
        """.data(using: .utf8)!
    }

    func testDecodesV4KerahatIntervalsAndLabels() throws {
        let snapshot = try WidgetSnapshot.decode(jsonV4)
        XCTAssertEqual(snapshot.days[0].kerahat, [
            SnapshotInterval(start: "06:06", end: "06:51"),
            SnapshotInterval(start: "12:45", end: "12:55"),
            SnapshotInterval(start: "18:47", end: "19:32"),
        ])
        XCTAssertEqual(snapshot.labels?.kerahat, "Kerahat")
        XCTAssertEqual(snapshot.labels?.kerahatSoon, "Kerahate")
    }

    /// `kerahatSoon` sonradan eklendi (2026-09-21); alan olmayan v4 payload
    /// yine çözülür, şerit Türkçe varsayılana düşer.
    func testV4WithoutKerahatSoonDecodes() throws {
        let json = String(data: jsonV4, encoding: .utf8)!
            .replacingOccurrences(of: #", "kerahatSoon": "Kerahate""#, with: "")
        let snapshot = try WidgetSnapshot.decode(json.data(using: .utf8)!)
        XCTAssertEqual(snapshot.labels?.kerahat, "Kerahat")
        XCTAssertNil(snapshot.labels?.kerahatSoon)
    }

    /// Eski payload'da kerahat yok: satir cizilmez, widget calismaya devam eder.
    func testV3WithoutKerahatDecodesToNil() throws {
        let snapshot = try WidgetSnapshot.decode(jsonV2(schemaVersion: 3))
        XCTAssertNil(snapshot.days[0].kerahat)
    }

    /// 2026-10-08 turu: günlere tarih metinleri ve cetvel eklendi; şema 4 kalır.
    private var jsonV4Ruler: Data {
        """
        {
          "schemaVersion": 4,
          "locationLabel": "İstanbul (Merkez)",
          "generatedAt": "2026-10-08T12:42:00",
          "days": [
            { "date": "2026-10-08",
              "hijri": "27 Rebiülahir 1448",
              "times": { "fajr": "05:36", "sunrise": "07:01", "dhuhr": "12:57",
                         "asr": "16:08", "maghrib": "18:43", "isha": "20:02" },
              "kerahat": [ { "start": "12:47", "end": "12:57" } ],
              "weekday": "Perşembe",
              "dateLabel": "8 Ekim",
              "hijriShort": "27 Rebiülahir",
              "epochs": { "fajr": 1791427000000 },
              "ruler": {
                "segments": [
                  { "start": 0.0, "end": 0.2333, "kind": "night", "gapBefore": false, "gapAfter": true },
                  { "start": 0.2333, "end": 0.5326, "kind": "day", "gapBefore": true, "gapAfter": false },
                  { "start": 0.5326, "end": 0.5396, "kind": "kerahat", "gapBefore": false, "gapAfter": true }
                ],
                "marks": [0.2333, 0.2924, 0.5396, 0.6722, 0.7799, 0.8347]
              } }
          ],
          "timeline": [ { "at": 1791452520000, "day": 0, "slot": 2, "tomorrow": false,
                          "phase": "morning", "kerahat": null } ]
        }
        """.data(using: .utf8)!
    }

    func testDecodesDateLabelsAndRuler() throws {
        let day = try WidgetSnapshot.decode(jsonV4Ruler).days[0]
        XCTAssertEqual(day.weekday, "Perşembe")
        XCTAssertEqual(day.dateLabel, "8 Ekim")
        XCTAssertEqual(day.hijriShort, "27 Rebiülahir")
        let ruler = try XCTUnwrap(day.ruler)
        // Ondalıklar JSON'dan geçer; birebir eşitlik yerine payla karşılaştırılır.
        XCTAssertEqual(ruler.marks.count, 6)
        for (mark, expected) in zip(ruler.marks, [0.2333, 0.2924, 0.5396, 0.6722, 0.7799, 0.8347]) {
            XCTAssertEqual(mark, expected, accuracy: 1e-9)
        }
        XCTAssertEqual(ruler.segments.count, 3)
        let first = ruler.segments[0]
        XCTAssertEqual(first.start, 0, accuracy: 1e-9)
        XCTAssertEqual(first.end, 0.2333, accuracy: 1e-9)
        XCTAssertEqual(first.kind, .night)
        XCTAssertFalse(first.gapBefore)
        XCTAssertTrue(first.gapAfter)
        XCTAssertEqual(ruler.segments[1].kind, .day)
        XCTAssertTrue(ruler.segments[1].gapBefore)
        XCTAssertEqual(ruler.segments[2].kind, .kerahat)
        // Eski alanlar etkilenmez.
        XCTAssertEqual(day.kerahat, [SnapshotInterval(start: "12:47", end: "12:57")])
        XCTAssertEqual(day.times.dhuhr, "12:57")
    }

    /// Eski uygulamanın v4 payload'ında yeni alanlar yok: çözülür, alanlar nil.
    func testV4WithoutNewFieldsDecodesToNil() throws {
        let day = try WidgetSnapshot.decode(jsonV4).days[0]
        XCTAssertNil(day.weekday)
        XCTAssertNil(day.dateLabel)
        XCTAssertNil(day.hijriShort)
        XCTAssertNil(day.ruler)
        XCTAssertEqual(day.kerahat?.count, 3)
    }

    /// Bozuk cetvel (bilinmeyen parça türü) yalnız cetveli düşürür; widget
    /// "uygulamayı aç"a düşmez.
    func testMalformedRulerDropsOnlyTheRuler() throws {
        let json = String(data: jsonV4Ruler, encoding: .utf8)!
            .replacingOccurrences(of: #""kind": "day""#, with: #""kind": "dawn""#)
        let day = try WidgetSnapshot.decode(json.data(using: .utf8)!).days[0]
        XCTAssertNil(day.ruler)
        XCTAssertEqual(day.weekday, "Perşembe")
        XCTAssertEqual(day.times.fajr, "05:36")
    }

    /// Tarih metni beklenmeyen türde gelirse yalnız o alan düşer.
    func testMalformedDateLabelDropsOnlyThatField() throws {
        let json = String(data: jsonV4Ruler, encoding: .utf8)!
            .replacingOccurrences(of: #""dateLabel": "8 Ekim""#, with: #""dateLabel": 8"#)
        let day = try WidgetSnapshot.decode(json.data(using: .utf8)!).days[0]
        XCTAssertNil(day.dateLabel)
        XCTAssertEqual(day.weekday, "Perşembe")
        XCTAssertNotNil(day.ruler)
    }
}

// MARK: - Cetvel geometrisi (aynı test hedefinde; proje dosyası değişmesin)

final class RulerGeometryTests: XCTestCase {
    private func segment(
        _ start: Double, _ end: Double, _ kind: RulerSegmentKind = .day,
        gapBefore: Bool = false, gapAfter: Bool = false
    ) -> SnapshotRulerSegment {
        SnapshotRulerSegment(
            start: start, end: end, kind: kind, gapBefore: gapBefore, gapAfter: gapAfter)
    }

    /// Vakit sınırında iki parça boşluğun yarısını verir: toplam 3 pt.
    func testSpansLeaveGapAtPrayerBoundaries() {
        let spans = RulerGeometry.spans(
            segments: [
                segment(0, 0.25, .night, gapAfter: true),
                segment(0.25, 1, .day, gapBefore: true),
            ],
            width: 200)
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans[0].x0, 0, accuracy: 1e-9)
        XCTAssertEqual(spans[0].x1, 48.5, accuracy: 1e-9)
        XCTAssertEqual(spans[1].x0, 51.5, accuracy: 1e-9)
        XCTAssertEqual(spans[1].x1, 200, accuracy: 1e-9)
        XCTAssertEqual(spans[1].x0 - spans[0].x1, RulerGeometry.markGap, accuracy: 1e-9)
        XCTAssertEqual(spans[0].kind, .night)
        XCTAssertEqual(spans[1].kind, .day)
    }

    /// Gün uçları ve vakit boşlukları yuvarlak; kerahat sınırı düz birleşir.
    func testRoundingAtDayEdgesAndGapsOnly() {
        let spans = RulerGeometry.spans(
            segments: [
                segment(0, 0.5, .day, gapAfter: false),
                segment(0.5, 0.6, .kerahat, gapAfter: true),
                segment(0.6, 1, .night, gapBefore: true),
            ],
            width: 100)
        XCTAssertEqual(spans.map(\.roundLeading), [true, false, true])
        XCTAssertEqual(spans.map(\.roundTrailing), [false, true, true])
        // Kerahat sınırında boşluk yok.
        XCTAssertEqual(spans[1].x0, spans[0].x1, accuracy: 1e-9)
    }

    /// Boşluklar düşünce genişliği kalmayan, ters ya da bozuk parça çizilmez;
    /// taşan oranlar kırpılır.
    func testDropsEmptyInvertedAndNonFiniteSegments() {
        let spans = RulerGeometry.spans(
            segments: [
                segment(0.5, 0.51, gapBefore: true, gapAfter: true),  // 1 pt < 3 pt boşluk
                segment(0.7, 0.6),
                segment(.nan, 0.8),
                segment(0.9, 1.2),
            ],
            width: 100)
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].x0, 90, accuracy: 1e-9)
        XCTAssertEqual(spans[0].x1, 100, accuracy: 1e-9)
        XCTAssertTrue(spans[0].roundTrailing)
    }

    func testNoSpansForZeroWidth() {
        XCTAssertTrue(RulerGeometry.spans(segments: [segment(0, 1)], width: 0).isEmpty)
    }

    /// Uçtaki çentik de cetvelin içinde kalır; bozuk oran düşer.
    func testMarkXsKeepTicksInside() {
        let xs = RulerGeometry.markXs(marks: [0, 0.5, 1, -0.1, .infinity], width: 102)
        XCTAssertEqual(xs.count, 3)
        XCTAssertEqual(xs[0], 0, accuracy: 1e-9)
        XCTAssertEqual(xs[1], 50, accuracy: 1e-9)
        XCTAssertEqual(xs[2], 100, accuracy: 1e-9)
    }

    /// Nokta kenarlarda yarıçap kadar içeride kırpılır.
    func testDotCenterIsClampedAtEdges() {
        let half = RulerGeometry.dotSize / 2
        XCTAssertEqual(RulerGeometry.dotCenterX(fraction: 0, width: 300), half, accuracy: 1e-9)
        XCTAssertEqual(RulerGeometry.dotCenterX(fraction: 1, width: 300), 300 - half, accuracy: 1e-9)
        XCTAssertEqual(RulerGeometry.dotCenterX(fraction: 0.5, width: 300), 150, accuracy: 1e-9)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }

    private func at(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    func testDayFractionWithinShownDay() throws {
        let fraction = try XCTUnwrap(
            RulerGeometry.dayFraction(now: at(8, 12, 0), day: "2026-10-08", calendar: calendar))
        XCTAssertEqual(fraction, 0.5, accuracy: 1e-9)
        XCTAssertEqual(
            RulerGeometry.dayFraction(now: at(8, 0, 0), day: "2026-10-08", calendar: calendar) ?? -1,
            0, accuracy: 1e-9)
    }

    /// Yatsı'dan sonra liste yarını gösterir: nokta çizilmez.
    func testDayFractionIsNilWhenShownDayIsNotToday() {
        XCTAssertNil(RulerGeometry.dayFraction(now: at(8, 21, 0), day: "2026-10-09", calendar: calendar))
        XCTAssertNil(RulerGeometry.dayFraction(now: at(9, 0, 0), day: "2026-10-08", calendar: calendar))
        XCTAssertNil(RulerGeometry.dayFraction(now: at(8, 12, 0), day: "bozuk", calendar: calendar))
    }

    /// Yükseklik nokta + çentik (iOS'ta saat etiketi yok); nokta yokken de aynı.
    func testHeightStacksDotAndTicks() {
        XCTAssertEqual(RulerGeometry.trackCenter, 7, accuracy: 1e-9)
        XCTAssertEqual(RulerGeometry.tickTop, 11.5, accuracy: 1e-9)
        XCTAssertEqual(RulerGeometry.height, 17.5, accuracy: 1e-9)
    }
}
