import XCTest

final class CountdownTextTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func text(after seconds: TimeInterval) -> String {
        CountdownText.format(from: base, to: base.addingTimeInterval(seconds))
    }

    /// Sistem "5:34:42" yaziyor; biz saniyeyi tire yapip geri kalanini birebir
    /// taklit ediyoruz. Sifir dolgusu yok.
    func testHoursMinutesWithDashedSeconds() {
        XCTAssertEqual(text(after: 5 * 3600 + 34 * 60 + 42), "5:34:--")
    }

    func testMinutesArePaddedOnlyWhenHoursPresent() {
        XCTAssertEqual(text(after: 5 * 3600 + 4 * 60), "5:04:--")
    }

    /// Bir saatin altinda sistem "34:42" yaziyor, saat hanesi hic cikmiyor.
    func testUnderAnHourDropsTheHour() {
        XCTAssertEqual(text(after: 34 * 60 + 42), "34:--")
    }

    func testUnderTenMinutesIsNotPadded() {
        XCTAssertEqual(text(after: 9 * 60 + 5), "9:--")
    }

    func testPastDeadlineClampsToZero() {
        XCTAssertEqual(text(after: -120), "0:--")
    }

    /// Saniye kalintisi asagi yuvarlanir; 59 saniye kala hala "0:--".
    func testPartialMinuteRoundsDown() {
        XCTAssertEqual(text(after: 59), "0:--")
    }
}
