import XCTest
@testable import Runner

final class AlarmJournalTests: XCTestCase {
  func testJournalIsBoundedRetainsFailuresAndOmitsUserLabel() throws {
    let domain = "alarm-journal-test-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let journal = AlarmJournal(defaults: defaults, limit: 3, retentionMillis: 1000)
    let config = AlarmMissionConfiguration(scheduleId: "a#at10", alarmId: "a",
      label: "PRIVATE_LABEL", fireAtMillis: 10)
    journal.record("old", at: 1)
    journal.record("schedule", at: 2000, configuration: config, result: "failed",
      error: NSError(domain: "TestFailure", code: 7))
    journal.record("scheduled", at: 2001, configuration: config)
    journal.record("reconcile", at: 2002)
    XCTAssertEqual(journal.entries.count, 3)
    XCTAssertEqual(journal.entries.first?.errorCode, "TestFailure:7")
    let data = try XCTUnwrap(defaults.data(forKey: "ezanvakti_alarm_journal_v1"))
    XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("PRIVATE_LABEL"))
    journal.record("last", at: 2003)
    XCTAssertEqual(journal.entries.count, 3)
    XCTAssertEqual(journal.entries.last?.operation, "last")
  }
}
