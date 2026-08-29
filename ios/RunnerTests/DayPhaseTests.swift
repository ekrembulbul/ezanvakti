import XCTest

final class DayPhaseTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private var slots: [PrayerSlot] {
        NextPrayer.slots(
            days: [SnapshotDay(
                date: "2026-08-25",
                hijri: "13 Rebiülevvel 1448",
                times: SnapshotTimes(
                    fajr: "04:12", sunrise: "05:52", dhuhr: "13:15",
                    asr: "16:58", maghrib: "20:26", isha: "21:58"
                )
            )],
            calendar: calendar
        )
    }

    private func at(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 25, hour: hour, minute: minute
        ))!
    }

    func testBeforeFajrIsNight() {
        XCTAssertEqual(
            DayPhase.resolve(slots: slots, now: at(2, 0), calendar: calendar), .night
        )
    }

    func testBetweenFajrAndDhuhrIsMorning() {
        XCTAssertEqual(
            DayPhase.resolve(slots: slots, now: at(6, 0), calendar: calendar), .morning
        )
    }

    func testBetweenDhuhrAndAsrIsAfternoon() {
        XCTAssertEqual(
            DayPhase.resolve(slots: slots, now: at(15, 0), calendar: calendar), .afternoon
        )
    }

    /// Gece Akşam'da değil Yatsı'da başlar (day_phase.dart:4-8).
    func testBetweenMaghribAndIshaIsStillEvening() {
        XCTAssertEqual(
            DayPhase.resolve(slots: slots, now: at(21, 0), calendar: calendar), .evening
        )
    }

    func testAfterIshaIsNight() {
        XCTAssertEqual(
            DayPhase.resolve(slots: slots, now: at(22, 0), calendar: calendar), .night
        )
    }

    /// Sınır anı bir SONRAKİ dilime aittir (day_phase.dart:20-21).
    func testBoundaryBelongsToNextPhase() {
        XCTAssertEqual(
            DayPhase.resolve(slots: slots, now: at(13, 15), calendar: calendar), .afternoon
        )
    }

    func testFallsBackToEveningWithoutData() {
        XCTAssertEqual(
            DayPhase.resolve(slots: [], now: at(13, 0), calendar: calendar), DayPhase.fallback
        )
        XCTAssertEqual(DayPhase.fallback, .evening)
    }
}
