import XCTest

final class KerahatChipLabelTests: XCTestCase {
    private let zone = TimeZone(identifier: "Europe/Istanbul")!
    private let locale = Locale(identifier: "tr_TR")

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
    private let fullLabels = #"{"kerahat":"Kerahat","kerahatActive":"Kerahat vakti","kerahatUntil":"bitiş {time}"}"#

    func testApproachingWritesLabelAndStartTimeWithoutSuffix() throws {
        let text = KerahatChipLabel.text(
            status: approaching, compact: true,
            labels: try labels(#"{"kerahat":"Kerahat"}"#),
            timeFormat: .h24, locale: locale, timeZone: zone)
        XCTAssertEqual(text, "Kerahat 18:38")
    }

    func testApproachingIsSameOnMedium() throws {
        let text = KerahatChipLabel.text(
            status: approaching, compact: false,
            labels: try labels(#"{"kerahat":"Kerahat"}"#),
            timeFormat: .h24, locale: locale, timeZone: zone)
        XCTAssertEqual(text, "Kerahat 18:38")
    }

    func testActiveCompactUsesActiveLabelOnly() throws {
        let text = KerahatChipLabel.text(
            status: active, compact: true,
            labels: try labels(fullLabels),
            timeFormat: .h24, locale: locale, timeZone: zone)
        XCTAssertEqual(text, "Kerahat vakti")
    }

    func testActiveMediumAppendsUntil() throws {
        let text = KerahatChipLabel.text(
            status: active, compact: false,
            labels: try labels(fullLabels),
            timeFormat: .h24, locale: locale, timeZone: zone)
        XCTAssertEqual(text, "Kerahat · bitiş 19:23")
    }

    func testFallsBackToTurkishWithoutLabels() {
        XCTAssertEqual(
            KerahatChipLabel.text(
                status: active, compact: true, labels: nil,
                timeFormat: .h24, locale: locale, timeZone: zone),
            "Kerahat vakti")
        XCTAssertEqual(
            KerahatChipLabel.text(
                status: active, compact: false, labels: nil,
                timeFormat: .h24, locale: locale, timeZone: zone),
            "Kerahat · bitiş 19:23")
        XCTAssertEqual(
            KerahatChipLabel.text(
                status: approaching, compact: true, labels: nil,
                timeFormat: .h24, locale: locale, timeZone: zone),
            "Kerahat 18:38")
    }

    func testTwelveHourPreference() {
        let text = KerahatChipLabel.text(
            status: approaching, compact: true, labels: nil,
            timeFormat: .h12, locale: Locale(identifier: "en_US"), timeZone: zone)
        XCTAssertEqual(text, "Kerahat 6:38 PM")
    }

    func testEntryIsKerahatActiveOnlyInActiveState() {
        var entry = PrayerEntry(date: at(18, 50), content: .noData)
        XCTAssertFalse(entry.isKerahatActive)
        entry.kerahat = approaching
        XCTAssertFalse(entry.isKerahatActive)
        entry.kerahat = active
        XCTAssertTrue(entry.isKerahatActive)
    }
}
