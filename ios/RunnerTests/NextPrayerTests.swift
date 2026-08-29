import XCTest

final class NextPrayerTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ date: String) -> SnapshotDay {
        SnapshotDay(
            date: date,
            times: SnapshotTimes(
                fajr: "04:12", sunrise: "05:52", dhuhr: "13:15",
                asr: "16:58", maghrib: "20:26", isha: "21:58"
            )
        )
    }

    private func at(_ year: Int, _ month: Int, _ day: Int,
                    _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    func testResolvesNextPrayerWithinDay() {
        let slot = NextPrayer.resolve(
            days: [day("2026-08-25")],
            now: at(2026, 8, 25, 14, 0),
            calendar: calendar
        )
        XCTAssertEqual(slot?.name, "İkindi")
        XCTAssertEqual(slot?.date, at(2026, 8, 25, 16, 58))
    }

    func testAfterIshaRollsToNextDayFajr() {
        let slot = NextPrayer.resolve(
            days: [day("2026-08-25"), day("2026-08-26")],
            now: at(2026, 8, 25, 22, 30),
            calendar: calendar
        )
        XCTAssertEqual(slot?.name, "İmsak")
        XCTAssertEqual(slot?.date, at(2026, 8, 26, 4, 12))
    }

    func testBeforeFajrResolvesToSameDayFajr() {
        let slot = NextPrayer.resolve(
            days: [day("2026-08-25")],
            now: at(2026, 8, 25, 2, 0),
            calendar: calendar
        )
        XCTAssertEqual(slot?.name, "İmsak")
    }

    func testReturnsNilWhenWindowExhausted() {
        let slot = NextPrayer.resolve(
            days: [day("2026-08-25")],
            now: at(2026, 8, 25, 23, 59),
            calendar: calendar
        )
        XCTAssertNil(slot)
    }

    func testSlotsAreSortedAndNamedLikeTheApp() {
        let slots = NextPrayer.slots(days: [day("2026-08-25")], calendar: calendar)
        XCTAssertEqual(
            slots.map(\.name),
            ["İmsak", "Güneş", "Öğle", "İkindi", "Akşam", "Yatsı"]
        )
    }

    func testMalformedTimeIsSkippedInsteadOfCrashing() {
        let broken = SnapshotDay(
            date: "2026-08-25",
            times: SnapshotTimes(
                fajr: "bozuk", sunrise: "05:52", dhuhr: "13:15",
                asr: "16:58", maghrib: "20:26", isha: "21:58"
            )
        )
        let slots = NextPrayer.slots(days: [broken], calendar: calendar)
        XCTAssertEqual(slots.count, 5)
        XCTAssertFalse(slots.contains { $0.name == "İmsak" })
    }
}
