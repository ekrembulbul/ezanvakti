import XCTest

final class PrayerTimelineTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func snapshot(days: [String]) -> WidgetSnapshot {
        WidgetSnapshot(
            schemaVersion: 2,
            locationLabel: "Kadıköy, İstanbul",
            days: days.map {
                SnapshotDay(
                    date: $0,
                    hijri: "13 Rebiülevvel 1448",
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

    private func entries(days: [String], now: Date) -> [PrayerEntry] {
        PrayerTimeline.entries(
            for: .success(snapshot(days: days)), now: now, calendar: calendar
        )
    }

    func testNoSnapshotProducesSingleNoDataEntry() {
        let result = PrayerTimeline.entries(for: nil, now: at(25, 14, 0), calendar: calendar)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].content, .noData)
    }

    func testUnsupportedSchemaProducesNeedsUpdateEntry() {
        let result = PrayerTimeline.entries(
            for: .failure(.unsupportedSchema), now: at(25, 14, 0), calendar: calendar
        )
        XCTAssertEqual(result[0].content, .needsUpdate)
    }

    func testEmptySnapshotProducesNoDataEntry() {
        let result = entries(days: [], now: at(25, 14, 0))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].content, .noData)
    }

    func testFirstEntryStartsAtNow() {
        XCTAssertEqual(
            entries(days: ["2026-08-25", "2026-08-26"], now: at(25, 14, 0)).first?.date,
            at(25, 14, 0)
        )
    }

    func testEntriesAreOneMinuteApart() {
        let result = entries(days: ["2026-08-25", "2026-08-26"], now: at(25, 14, 0))
        XCTAssertEqual(result[0].date, at(25, 14, 0))
        XCTAssertEqual(result[1].date, at(25, 14, 1))
        XCTAssertEqual(result[2].date, at(25, 14, 2))
    }

    func testWindowCoversTwoHours() {
        let result = entries(days: ["2026-08-25", "2026-08-26"], now: at(25, 14, 0))
        XCTAssertEqual(result.count, PrayerTimeline.windowMinutes + 1)
        XCTAssertEqual(result.last?.date, at(25, 16, 0))
    }

    func testEntryCarriesItsOwnDayPhase() {
        let result = entries(days: ["2026-08-25", "2026-08-26"], now: at(25, 14, 0))
        guard case let .ready(_, _, phase, _, _, _) = result[0].content else {
            return XCTFail("ready bekleniyordu")
        }
        XCTAssertEqual(phase, .afternoon)
    }

    /// M3/M4: 23:00'te siradaki vakit yarinin Imsak'i; liste de yarini
    /// gostermeli, yoksa iki sutun farkli gune bakar ve vurgu listede
    /// karsilik bulmaz.
    func testListFollowsTheDayOfTheNextPrayer() {
        let result = entries(days: ["2026-08-25", "2026-08-26"], now: at(25, 23, 0))
        guard case let .ready(next, day, _, _, _, isTomorrow) = result[0].content else {
            return XCTFail("ready bekleniyordu")
        }
        XCTAssertEqual(next.name, "İmsak")
        XCTAssertEqual(day.date, "2026-08-26")
        XCTAssertTrue(isTomorrow)
    }

    func testIsTomorrowIsFalseWithinTheSameDay() {
        let result = entries(days: ["2026-08-25", "2026-08-26"], now: at(25, 14, 0))
        guard case let .ready(_, day, _, _, _, isTomorrow) = result[0].content else {
            return XCTFail("ready bekleniyordu")
        }
        XCTAssertEqual(day.date, "2026-08-25")
        XCTAssertFalse(isTomorrow)
    }

    /// Pencere icinde vakit gecince o girisin siradakisi degismeli.
    func testEntryAfterBoundaryAdvancesToTheNextPrayer() {
        let result = entries(days: ["2026-08-25", "2026-08-26"], now: at(25, 16, 57))
        guard case let .ready(before, _, _, _, _, _) = result[0].content,
              case let .ready(after, _, _, _, _, _) = result[2].content else {
            return XCTFail("ready bekleniyordu")
        }
        XCTAssertEqual(before.name, "İkindi")
        XCTAssertEqual(after.name, "Akşam")
    }

    func testStaleSnapshotIsMarked() {
        let result = entries(days: ["2026-08-20"], now: at(25, 14, 0))
        guard case let .ready(_, _, _, _, isStale, _) = result[0].content else {
            return XCTFail("ready bekleniyordu, gelen: \(result[0].content)")
        }
        XCTAssertTrue(isStale)
    }
}
