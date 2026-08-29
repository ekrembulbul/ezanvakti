import XCTest

final class WidgetSnapshotTests: XCTestCase {
    private func json(schemaVersion: Int) -> Data {
        """
        {
          "schemaVersion": \(schemaVersion),
          "locationLabel": "Kadıköy, İstanbul",
          "generatedAt": "2026-08-25T14:03:00",
          "days": [
            { "date": "2026-08-25",
              "times": { "fajr": "04:12", "sunrise": "05:52", "dhuhr": "13:15",
                         "asr": "16:58", "maghrib": "20:26", "isha": "21:58" } }
          ]
        }
        """.data(using: .utf8)!
    }

    func testDecodesValidPayload() throws {
        let snapshot = try WidgetSnapshot.decode(json(schemaVersion: 1))
        XCTAssertEqual(snapshot.locationLabel, "Kadıköy, İstanbul")
        XCTAssertEqual(snapshot.days.count, 1)
        XCTAssertEqual(snapshot.days[0].times.asr, "16:58")
    }

    func testRejectsUnknownSchemaVersion() {
        XCTAssertThrowsError(try WidgetSnapshot.decode(json(schemaVersion: 99))) { error in
            XCTAssertEqual(error as? SnapshotLoadError, .unsupportedSchema)
        }
    }

    func testRejectsMalformedPayload() {
        let broken = "{ not json".data(using: .utf8)!
        XCTAssertThrowsError(try WidgetSnapshot.decode(broken)) { error in
            XCTAssertEqual(error as? SnapshotLoadError, .malformed)
        }
    }
}
