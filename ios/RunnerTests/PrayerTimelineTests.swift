import XCTest

final class PrayerTimelineTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func snapshot(days: [String]) -> WidgetSnapshot {
        WidgetSnapshot(
            schemaVersion: 2,
            locationLabel: "Kadıköy, İstanbul",
            days: days.map {
                SnapshotDay(
                    date: $0,
                    hijri: "13 Rebiülevvel 1448",
                    times: SnapshotTimes(
                        fajr: "04:12", sunrise: "05:52", dhuhr: "13:15",
                        asr: "16:58", maghrib: "20:26", isha: "21:58"
                    )
                )
            },
            labels: nil
        )
    }

    private func at(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(
            year: 2026, month: 8, day: day, hour: hour, minute: minute
        ))!
    }

    private func entries(days: [String], now: Date) -> [PrayerEntry] {
        PrayerTimeline.entries(
            for: .success(snapshot(days: days)), now: now, calendar: calendar
        )
    }

    func testNoSnapshotProducesSingleNoDataEntry() {
        let result = PrayerTimeline.entries(for: nil, now: at(25, 14, 0), calendar: calendar)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].content, .noData)
    }

    func testUnsupportedSchemaProducesNeedsUpdateEntry() {
        let result = PrayerTimeline.entries(
            for: .failure(.unsupportedSchema), now: at(25, 14, 0), calendar: calendar
        )
        XCTAssertEqual(result[0].content, .needsUpdate)
    }

    func testEmptySnapshotProducesNoDataEntry() {
        let result = entries(days: [], now: at(25, 14, 0))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].content, .noData)
    }

    func testFirstEntryStartsAtNow() {
        XCTAssertEqual(
            entries(days: ["2026-08-25", "2026-08-26"], now: at(25, 14, 0)).first?.date,
            at(25, 14, 0)
        )
    }

    /// Geri sayimi sistem cizdigi icin kare yalnizca icerik degisince gerekir:
    /// her vakit gecisinde. Dakikalik kare uretimi 0.5.4'te olculup kaldirildi.
    func testEntriesLandOnPrayerBoundariesOnly() {
        let result = entries(days: ["2026-08-25", "2026-08-26"], now: at(25, 14, 0))
        XCTAssertEqual(result[1].date, at(25, 16, 58))  // İkindi
        XCTAssertEqual(result[2].date, at(25, 20, 26))  // Akşam
        XCTAssertEqual(result[3].date, at(25, 21, 58))  // Yatsı
        XCTAssertEqual(result[4].date, at(26, 4, 12))   // ertesi İmsak
    }

    func testHorizonIsCapped() {
        let result = entries(
            days: ["2026-08-25", "2026-08-26", "2026-08-27", "2026-08-28"],
            now: at(25, 14, 0)
        )
        XCTAssertLessThanOrEqual(result.count, PrayerTimeline.maxEntries)
        let horizon = at(25, 14, 0).addingTimeInterval(
            TimeInterval(PrayerTimeline.horizonHours * 3600)
        )
        XCTAssertTrue(result.allSatisfy { $0.date <= horizon })
    }

    func testEntryAtBoundaryAdvancesToTheNextPrayer() {
        let result = entries(days: ["2026-08-25", "2026-08-26"], now: at(25, 14, 0))
        guard case let .ready(first, _, _, _, _, _) = result[0].content,
              case let .ready(second, _, _, _, _, _) = result[1].content else {
            return XCTFail("ready bekleniyordu")
        }
        XCTAssertEqual(first.name, "İkindi")
        XCTAssertEqual(second.name, "Akşam")
    }

    func testEntryCarriesItsOwnDayPhase() {
        let result = entries(days: ["2026-08-25", "2026-08-26"], now: at(25, 14, 0))
        guard case let .ready(_, _, phase, _, _, _) = result[0].content else {
            return XCTFail("ready bekleniyordu")
        }
        XCTAssertEqual(phase, .afternoon)
    }

    func testListFollowsTheDayOfTheNextPrayer() {
        let result = entries(days: ["2026-08-25", "2026-08-26"], now: at(25, 23, 0))
        guard case let .ready(next, day, _, _, _, isTomorrow) = result[0].content else {
            return XCTFail("ready bekleniyordu")
        }
        XCTAssertEqual(next.name, "İmsak")
        XCTAssertEqual(day.date, "2026-08-26")
        XCTAssertTrue(isTomorrow)
    }

    func testIsTomorrowIsFalseWithinTheSameDay() {
        let result = entries(days: ["2026-08-25", "2026-08-26"], now: at(25, 14, 0))
        guard case let .ready(_, day, _, _, _, isTomorrow) = result[0].content else {
            return XCTFail("ready bekleniyordu")
        }
        XCTAssertEqual(day.date, "2026-08-25")
        XCTAssertFalse(isTomorrow)
    }

    func testStaleSnapshotIsMarked() {
        let result = entries(days: ["2026-08-20"], now: at(25, 14, 0))
        guard case let .ready(_, _, _, _, isStale, _) = result[0].content else {
            return XCTFail("ready bekleniyordu, gelen: \(result[0].content)")
        }
        XCTAssertTrue(isStale)
    }

    // MARK: - Kerahat

    private func kerahatSnapshot(days: [String]) -> WidgetSnapshot {
        WidgetSnapshot(
            schemaVersion: 4,
            locationLabel: "Kadıköy, İstanbul",
            days: days.map {
                SnapshotDay(
                    date: $0,
                    hijri: "13 Rebiülevvel 1448",
                    times: SnapshotTimes(
                        fajr: "04:12", sunrise: "05:52", dhuhr: "13:15",
                        asr: "16:58", maghrib: "20:26", isha: "21:58"
                    ),
                    kerahat: [
                        SnapshotInterval(start: "05:52", end: "06:37"),
                        SnapshotInterval(start: "13:05", end: "13:15"),
                        SnapshotInterval(start: "19:41", end: "20:26"),
                    ]
                )
            },
            labels: nil
        )
    }

    private func kerahatEntries(now: Date) -> [PrayerEntry] {
        PrayerTimeline.entries(
            for: .success(kerahatSnapshot(days: ["2026-08-25", "2026-08-26"])),
            now: now, calendar: calendar
        )
    }

    /// Kerahat satiri iceriktir: yaklasma ani (baslangic - 30 dk), baslangic
    /// ve bitis birer kare gerektirir; vakit sinirlari da yerinde kalir.
    func testEntriesIncludeKerahatMomentsBetweenPrayerBoundaries() {
        let dates = kerahatEntries(now: at(25, 14, 0)).map(\.date)
        XCTAssertEqual(Array(dates.prefix(6)), [
            at(25, 14, 0),   // simdi
            at(25, 16, 58),  // İkindi
            at(25, 19, 11),  // kerahat - 30 dk
            at(25, 19, 41),  // kerahat baslangici
            at(25, 20, 26),  // Akşam = kerahat bitisi
            at(25, 21, 58),  // Yatsı
        ])
        XCTAssertEqual(dates, dates.sorted())
        XCTAssertEqual(Set(dates).count, dates.count)
        XCTAssertLessThanOrEqual(dates.count, PrayerTimeline.maxEntries)
    }

    func testKerahatMomentsDoNotStarveNextDayPrayers() {
        let dates = kerahatEntries(now: at(25, 14, 0)).map(\.date)
        XCTAssertTrue(dates.contains(at(26, 13, 15)), "ertesi gunun oglesi 48 saatlik ufukta")
    }

    func testEntryCarriesApproachingKerahat() {
        let first = kerahatEntries(now: at(25, 19, 20))[0]
        XCTAssertEqual(first.kerahat, .approaching(start: at(25, 19, 41), end: at(25, 20, 26)))
    }

    func testEntryCarriesActiveKerahat() {
        let first = kerahatEntries(now: at(25, 19, 50))[0]
        XCTAssertEqual(first.kerahat, .active(end: at(25, 20, 26)))
    }

    func testEntryHasNoKerahatOutsideWindow() {
        XCTAssertNil(kerahatEntries(now: at(25, 14, 0))[0].kerahat)
        XCTAssertNil(kerahatEntries(now: at(25, 19, 10))[0].kerahat)
        XCTAssertNil(kerahatEntries(now: at(25, 20, 30))[0].kerahat)
    }

    func testSnapshotWithoutKerahatYieldsNoStatus() {
        XCTAssertNil(entries(days: ["2026-08-25"], now: at(25, 19, 20))[0].kerahat)
    }
}
