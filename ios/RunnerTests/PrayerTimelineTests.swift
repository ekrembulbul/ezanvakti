import XCTest

final class PrayerTimelineTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func snapshot(days: [String]) -> WidgetSnapshot {
        WidgetSnapshot(
            schemaVersion: 1,
            locationLabel: "Kadıköy, İstanbul",
            days: days.map {
                SnapshotDay(
                    date: $0,
                    times: SnapshotTimes(
                        fajr: "04:12", sunrise: "05:52", dhuhr: "13:15",
                        asr: "16:58", maghrib: "20:26", isha: "21:58"
                    )
                )
            }
        )
    }

    private func at(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(
            year: 2026, month: 8, day: day, hour: hour, minute: minute
        ))!
    }

    func testNoSnapshotProducesSingleNoDataEntry() {
        let entries = PrayerTimeline.entries(for: nil, now: at(25, 14, 0), calendar: calendar)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].content, .noData)
    }

    func testUnsupportedSchemaProducesNeedsUpdateEntry() {
        let entries = PrayerTimeline.entries(
            for: .failure(.unsupportedSchema), now: at(25, 14, 0), calendar: calendar
        )
        XCTAssertEqual(entries[0].content, .needsUpdate)
    }

    func testFirstEntryStartsAtNow() {
        let entries = PrayerTimeline.entries(
            for: .success(snapshot(days: ["2026-08-25", "2026-08-26"])),
            now: at(25, 14, 0), calendar: calendar
        )
        XCTAssertEqual(entries.first?.date, at(25, 14, 0))
    }

    func testEntriesLandOnPrayerBoundaries() {
        let entries = PrayerTimeline.entries(
            for: .success(snapshot(days: ["2026-08-25", "2026-08-26"])),
            now: at(25, 14, 0), calendar: calendar
        )
        XCTAssertEqual(entries[1].date, at(25, 16, 58))
        XCTAssertEqual(entries[2].date, at(25, 20, 26))
    }

    func testEntryKnowsItsOwnNextPrayer() {
        let entries = PrayerTimeline.entries(
            for: .success(snapshot(days: ["2026-08-25", "2026-08-26"])),
            now: at(25, 14, 0), calendar: calendar
        )
        guard case let .ready(next, _, _, _, _) = entries[1].content else {
            return XCTFail("ready bekleniyordu")
        }
        // İkindi girişinde sıradaki artık Akşam olmalı.
        XCTAssertEqual(next.name, "Akşam")
    }

    func testEntryCarriesItsOwnDayPhase() {
        let entries = PrayerTimeline.entries(
            for: .success(snapshot(days: ["2026-08-25", "2026-08-26"])),
            now: at(25, 14, 0), calendar: calendar
        )
        guard case let .ready(_, _, phase, _, _) = entries[0].content else {
            return XCTFail("ready bekleniyordu")
        }
        XCTAssertEqual(phase, .afternoon)
    }

    func testHorizonIsCapped() {
        let entries = PrayerTimeline.entries(
            for: .success(snapshot(days: [
                "2026-08-25", "2026-08-26", "2026-08-27", "2026-08-28",
            ])),
            now: at(25, 14, 0), calendar: calendar
        )
        XCTAssertLessThanOrEqual(entries.count, PrayerTimeline.maxEntries)
        let horizon = at(25, 14, 0).addingTimeInterval(
            TimeInterval(PrayerTimeline.horizonHours * 3600)
        )
        XCTAssertTrue(entries.allSatisfy { $0.date <= horizon })
    }

    func testStaleSnapshotIsMarked() {
        let entries = PrayerTimeline.entries(
            for: .success(snapshot(days: ["2026-08-20"])),
            now: at(25, 14, 0), calendar: calendar
        )
        guard case let .ready(_, _, _, _, isStale) = entries[0].content else {
            return XCTFail("ready bekleniyordu, gelen: \(entries[0].content)")
        }
        XCTAssertTrue(isStale)
    }

    func testEmptySnapshotProducesNoDataEntry() {
        let entries = PrayerTimeline.entries(
            for: .success(snapshot(days: [])), now: at(25, 14, 0), calendar: calendar
        )
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].content, .noData)
    }
}
