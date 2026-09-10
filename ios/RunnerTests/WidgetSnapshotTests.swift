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
          "labels": { "kerahat": "Kerahat", "kerahatActive": "Kerahat vakti",
                      "kerahatUntil": "bitiş {time}" }
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
        XCTAssertEqual(snapshot.labels?.kerahatActive, "Kerahat vakti")
        XCTAssertEqual(snapshot.labels?.kerahatUntil, "bitiş {time}")
    }

    /// Eski payload'da kerahat yok: satir cizilmez, widget calismaya devam eder.
    func testV3WithoutKerahatDecodesToNil() throws {
        let snapshot = try WidgetSnapshot.decode(jsonV2(schemaVersion: 3))
        XCTAssertNil(snapshot.days[0].kerahat)
    }
}
