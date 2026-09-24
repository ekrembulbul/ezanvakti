import XCTest

final class KerahatRibbonLabelTests: XCTestCase {
    private let zone = TimeZone(identifier: "Europe/Istanbul")!

    private func at(_ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 14, hour: hour, minute: minute
        ))!
    }

    /// Etiketler snapshot'tan JSON olarak geldiği için testte de öyle kurulur.
    private func labels(_ json: String) throws -> SnapshotLabels {
        try JSONDecoder().decode(SnapshotLabels.self, from: Data(json.utf8))
    }

    private var approaching: KerahatStatus { .approaching(start: at(18, 38), end: at(19, 23)) }
    private var active: KerahatStatus { .active(end: at(19, 23)) }

    private var snapshotLabels: SnapshotLabels {
        get throws {
            try labels(#"{"kerahat":"Disliked time","kerahatSoon":"Disliked time in"}"#)
        }
    }

    /// Yaklaşırken ayrı kelime: "Kerahat 13:41" kerahatin sürdüğü gibi
    /// okunuyordu (2026-09-21).
    func testLabelIsTheSingleWordFromSnapshotPerStatus() throws {
        XCTAssertEqual(
            KerahatRibbonLabel.text(labels: try snapshotLabels, status: active),
            "Disliked time")
        XCTAssertEqual(
            KerahatRibbonLabel.text(labels: try snapshotLabels, status: approaching),
            "Disliked time in")
    }

    func testLabelFallsBackToTurkishWithoutLabels() throws {
        XCTAssertEqual(KerahatRibbonLabel.text(labels: nil, status: active), "Kerahat")
        XCTAssertEqual(KerahatRibbonLabel.text(labels: nil, status: approaching), "Kerahate")
        // Eski uygulama yalnız "kerahat" yazar: yaklaşırken yine Türkçe varsayılan.
        let old = try labels(#"{"kerahat":"Disliked time"}"#)
        XCTAssertEqual(KerahatRibbonLabel.text(labels: old, status: approaching), "Kerahate")
    }

    func testCountdownTargetIsStartWhileApproachingAndEndWhileActive() {
        XCTAssertEqual(KerahatRibbonLabel.countdownTarget(status: approaching), at(18, 38))
        XCTAssertEqual(KerahatRibbonLabel.countdownTarget(status: active), at(19, 23))
    }
}
