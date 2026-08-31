import XCTest

@testable import Runner

final class MissionStopPolicyTests: XCTestCase {
    /// Gorevsizde durdurma kesin (spec 2026-08-30 D3): nobetci kurulmaz.
    func testUngatedNeverRearms() {
        XCTAssertEqual(
            MissionStopPolicy.action(
                gated: false, rearmCount: 0, maxRearms: 40,
                nowMillis: 0, chainDeadlineMillis: 1_000
            ),
            .ignore
        )
    }

    func testGatedWithinBoundsRearms() {
        XCTAssertEqual(
            MissionStopPolicy.action(
                gated: true, rearmCount: 3, maxRearms: 40,
                nowMillis: 0, chainDeadlineMillis: 1_000
            ),
            .rearm
        )
    }

    func testGatedStopsAtRearmCap() {
        XCTAssertEqual(
            MissionStopPolicy.action(
                gated: true, rearmCount: 40, maxRearms: 40,
                nowMillis: 0, chainDeadlineMillis: 1_000
            ),
            .stopChain
        )
    }

    func testGatedStopsPastDeadline() {
        XCTAssertEqual(
            MissionStopPolicy.action(
                gated: true, rearmCount: 0, maxRearms: 40,
                nowMillis: 2_000, chainDeadlineMillis: 1_000
            ),
            .stopChain
        )
    }
}

/// ISO (1=Pazartesi..7=Pazar) -> Locale.Weekday cevirisi; sirayi korur,
/// tanimsiz degerleri eler.
final class WeekdayMappingTests: XCTestCase {
    func testIsoWeekdayMapping() {
        XCTAssertEqual(
            AlarmKitHandler.localeWeekdays(fromIso: [1, 5, 7]),
            [.monday, .friday, .sunday])
    }

    func testUnknownValuesDropped() {
        XCTAssertEqual(AlarmKitHandler.localeWeekdays(fromIso: [0, 9]), [])
    }

    func testEveryDay() {
        XCTAssertEqual(
            AlarmKitHandler.localeWeekdays(fromIso: [1, 2, 3, 4, 5, 6, 7]),
            [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday])
    }
}
