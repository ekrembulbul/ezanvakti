import XCTest

@testable import Runner

final class MissionChainKeysTests: XCTestCase {
    private let keys = ["sahur", "sahur#w", "sahur#ladder0", "sahur#ladder1", "is", "is#w", "isci#w"]

    /// Gorev bitince yalnizca o alarmin zinciri silinmeli. Cihazda gorulen
    /// hata: cancelAll ayni gune kurulu diger alarmi da silmisti.
    func testSelectsOnlyTheChainOfTheGivenAlarm() {
        XCTAssertEqual(
            MissionChainKeys.select(alarmId: "sahur", from: keys),
            ["sahur#w", "sahur#ladder0", "sahur#ladder1"]
        )
    }

    /// Birincil alarm silinmez: oturum acilirken yeniden planlanmis olabilir
    /// ve ayni UUID'yi tasiyor; silinirse yarinki calis da gider.
    func testKeepsThePrimaryAlarm() {
        XCTAssertFalse(MissionChainKeys.select(alarmId: "sahur", from: keys).contains("sahur"))
    }

    func testDoesNotMatchLongerIdsSharingAPrefix() {
        XCTAssertEqual(MissionChainKeys.select(alarmId: "is", from: keys), ["is#w"])
    }
}
