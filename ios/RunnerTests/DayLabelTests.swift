import XCTest

final class DayLabelTests: XCTestCase {
    private func day(_ date: String) -> SnapshotDay {
        SnapshotDay(
            date: date,
            hijri: "13 Rebiülevvel 1448",
            times: SnapshotTimes(
                fajr: "04:37", sunrise: "06:06", dhuhr: "12:55",
                asr: "16:36", maghrib: "19:32", isha: "20:55"
            )
        )
    }

    /// Cihaz dili ne olursa olsun Turkce: uygulama tamamen Turkce.
    func testFormatsInTurkishRegardlessOfDeviceLocale() {
        XCTAssertEqual(DayLabel.gregorian(day("2026-08-29")), "Cumartesi, 29 Ağustos")
    }

    func testAnotherMonth() {
        XCTAssertEqual(DayLabel.gregorian(day("2026-01-02")), "Cuma, 2 Ocak")
    }

    func testMalformedDateReturnsNil() {
        XCTAssertNil(DayLabel.gregorian(day("bozuk")))
    }
}
