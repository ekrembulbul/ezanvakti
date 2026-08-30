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
