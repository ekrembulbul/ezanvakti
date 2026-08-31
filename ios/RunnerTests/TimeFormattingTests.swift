import XCTest

@testable import Runner

final class TimeFormattingTests: XCTestCase {
    private let reference: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 4
        components.hour = 19
        components.minute = 5
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: components)!
    }()

    private let utc = TimeZone(identifier: "UTC")!

    func testTwentyFourHour() {
        XCTAssertEqual(
            TimeFormatting.clock(
                reference, preference: .h24,
                locale: Locale(identifier: "tr_TR"), timeZone: utc),
            "19:05")
    }

    func testTwelveHour() {
        let value = TimeFormatting.clock(
            reference, preference: .h12,
            locale: Locale(identifier: "en_US"), timeZone: utc)
        XCTAssertEqual(value, "7:05 PM")
    }

    func testUnknownPreferenceFallsBackToSystem() {
        XCTAssertEqual(TimeFormatPreference.from("bilinmeyen"), .system)
        XCTAssertEqual(TimeFormatPreference.from(nil), .system)
        XCTAssertEqual(TimeFormatPreference.from("h12"), .h12)
    }
}
