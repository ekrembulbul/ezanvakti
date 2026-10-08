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

    func testShortLabelHasDayAndMonthOnly() {
        XCTAssertEqual(DayLabel.short(day("2026-09-14")), "14 Eylül")
    }

    func testShortLabelMalformedReturnsNil() {
        XCTAssertNil(DayLabel.short(day("bozuk")))
    }

    /// Uygulamanın dilinde payload metni (2026-10-08).
    private func labelled(
        weekday: String? = "Thursday", dateLabel: String? = "October 8",
        hijriShort: String? = "27 Rabi al-Akhir"
    ) -> SnapshotDay {
        var result = day("2026-10-08")
        result.weekday = weekday
        result.dateLabel = dateLabel
        result.hijriShort = hijriShort
        return result
    }

    func testGregorianPrefersPayloadText() {
        XCTAssertEqual(DayLabel.gregorian(labelled()), "Thursday, October 8")
    }

    /// Biri eksikse iki dil yan yana düşmesin: ikisi de Türkçe biçimden.
    func testGregorianFallsBackWhenOnePartMissing() {
        XCTAssertEqual(DayLabel.gregorian(labelled(dateLabel: nil)), "Perşembe, 8 Ekim")
        XCTAssertEqual(DayLabel.gregorian(labelled(weekday: "")), "Perşembe, 8 Ekim")
    }

    func testShortPrefersPayloadDateLabel() {
        XCTAssertEqual(DayLabel.short(labelled()), "October 8")
        XCTAssertEqual(DayLabel.short(labelled(dateLabel: nil)), "8 Ekim")
    }

    func testWeekdayPrefersPayloadAndFallsBackToTurkish() {
        XCTAssertEqual(DayLabel.weekday(labelled()), "Thursday")
        XCTAssertEqual(DayLabel.weekday(day("2026-10-08")), "Perşembe")
        XCTAssertNil(DayLabel.weekday(day("bozuk")))
    }

    func testHeaderJoinsDateAndShortHijri() {
        XCTAssertEqual(DayLabel.header(labelled()), "Thursday, October 8 · 27 Rabi al-Akhir")
    }

    /// Eski payload: yılsız hicri yok, yalnız miladi kalır.
    func testHeaderSkipsMissingHijri() {
        XCTAssertEqual(DayLabel.header(day("2026-10-08")), "Perşembe, 8 Ekim")
        XCTAssertEqual(DayLabel.header(labelled(hijriShort: "")), "Thursday, October 8")
    }

    func testHeaderWithNothingIsNil() {
        XCTAssertNil(DayLabel.header(day("bozuk")))
    }
}
