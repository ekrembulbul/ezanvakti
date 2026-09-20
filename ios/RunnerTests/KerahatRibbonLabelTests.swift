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

    func testLabelIsTheSingleWordFromSnapshot() throws {
        XCTAssertEqual(
            KerahatRibbonLabel.text(labels: try labels(#"{"kerahat":"Disliked time"}"#)),
            "Disliked time")
    }

    func testLabelFallsBackToTurkishWithoutLabels() {
        XCTAssertEqual(KerahatRibbonLabel.text(labels: nil), "Kerahat")
    }

    func testCountdownTargetIsStartWhileApproachingAndEndWhileActive() {
        XCTAssertEqual(KerahatRibbonLabel.countdownTarget(status: approaching), at(18, 38))
        XCTAssertEqual(KerahatRibbonLabel.countdownTarget(status: active), at(19, 23))
    }
}
