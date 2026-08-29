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
        XCTAssertEqual(text(after: 5 * 3600 + 4 * 60 + 30), "5:04:--")
    }

    /// Metin, girisin gecerli oldugu pencere boyunca sistemin gosterecegi
    /// dakikadir. Kalan sure tam 5:04:00 iken sonraki 59 saniye "5:03:xx"
    /// gorunecegi icin kare "5:03" der; "5:04" demek Always-On'u canli
    /// sayacin bir dakika onune gecirirdi.
    func testWholeMinuteShowsTheMinuteAboutToBeDisplayed() {
        XCTAssertEqual(text(after: 5 * 3600 + 4 * 60), "5:03:--")
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

    func testLastMinuteShowsZero() {
        XCTAssertEqual(text(after: 60), "0:--")
    }

    func testPartialMinuteRoundsDown() {
        XCTAssertEqual(text(after: 59), "0:--")
    }

    /// Saniye altı kesir yukarı yuvarlanır: 15900.4 sn kala sistem hâlâ
    /// "4:25:00" gösteriyor, biz de "4:25" demeliyiz.
    func testSubSecondRemainderDoesNotDropAMinute() {
        XCTAssertEqual(text(after: 4 * 3600 + 25 * 60 + 0.4), "4:25:--")
    }
}
