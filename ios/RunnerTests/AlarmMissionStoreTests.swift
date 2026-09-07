import XCTest
@testable import Runner

final class AlarmMissionStoreTests: XCTestCase {
  private var defaults: UserDefaults!
  private var domain: String!
  private var store: AlarmMissionStore!
  private let fire = 1_788_760_800_000.0

  override func setUp() {
    super.setUp()
    domain = "alarm-mission-test-\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: domain)!
    store = AlarmMissionStore(defaults: defaults)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: domain)
    super.tearDown()
  }

  private func configuration(_ id: String, fireAt: Double? = nil) -> AlarmMissionConfiguration {
    let time = fireAt ?? fire
    return AlarmMissionConfiguration(
      scheduleId: "\(id)#at\(Int64(time))", alarmId: id, label: id,
      fireAtMillis: time, gated: true, maxSnoozes: 2)
  }

  func testStopUsesItsOwnAlarmAfterOtherAlarmWasConfigured() throws {
    let work = configuration("is")
    try store.configure(work)
    try store.configure(configuration("yedek"))
    let stopped = try XCTUnwrap(store.stop(scheduleId: work.scheduleId, nowMillis: fire + 300_000))
    XCTAssertEqual(stopped.event.alarmId, "is")
    XCTAssertEqual(stopped.session.configuration.label, "is")
    XCTAssertEqual(stopped.event.firedAt, fire)
    XCTAssertEqual(stopped.event.stoppedAt, fire + 300_000)
    XCTAssertEqual(stopped.rearmAtMillis, fire + 330_000)
  }

  func testExpiredOtherAlarmDoesNotStopWorkMission() throws {
    let work = configuration("is")
    try store.configure(work)
    try store.configure(configuration("yedek", fireAt: fire - 7_200_000))
    let stopped = try XCTUnwrap(store.stop(scheduleId: work.scheduleId, nowMillis: fire + 1000))
    XCTAssertFalse(stopped.event.chainStopped)
    XCTAssertNotNil(stopped.rearmAtMillis)
  }

  func testFilteredConsumptionAndCompletionPreserveOtherAlarm() throws {
    for id in ["is", "yedek"] {
      let config = configuration(id)
      try store.configure(config)
      _ = try store.stop(scheduleId: config.scheduleId, nowMillis: fire + 1000)
    }
    XCTAssertEqual(try store.consume(alarmId: "is").map(\.alarmId), ["is"])
    _ = try store.finish(alarmId: "is")
    XCTAssertTrue(try XCTUnwrap(store.session(alarmId: "yedek")).pending)
    XCTAssertEqual(try store.consume().map(\.alarmId), ["yedek"])
  }

  func testConfigRefreshDoesNotOverwriteActiveSessionOrCounters() throws {
    let config = configuration("is")
    try store.configure(config)
    _ = try store.stop(scheduleId: config.scheduleId, nowMillis: fire + 1000)
    _ = try store.snooze(alarmId: "is", minutes: 5, nowMillis: fire + 2000)
    try store.configure(configuration("is", fireAt: fire + 86_400_000))
    let restored = AlarmMissionStore(defaults: defaults)
    XCTAssertEqual(restored.session(alarmId: "is")?.snoozeUsed, 1)
    XCTAssertEqual(restored.session(alarmId: "is")?.firedAtMillis, fire)
  }

  func testUnknownAndCompletedOccurrencesNeverBorrowAnotherSession() throws {
    let config = configuration("is")
    try store.configure(config)
    XCTAssertNil(try store.stop(scheduleId: "unknown", nowMillis: fire + 1000))
    _ = try store.stop(scheduleId: config.scheduleId, nowMillis: fire + 1000)
    _ = try store.finish(alarmId: "is")
    XCTAssertNil(try store.stop(scheduleId: config.scheduleId, nowMillis: fire + 2000))
    XCTAssertTrue(try store.consume().isEmpty)
  }

  func testWeeklyNextDayCreatesNewOccurrenceAndResetsCounters() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    var config = configuration("is")
    config.repeatWeekdays = [1, 2, 3, 4, 5, 6, 7]
    try store.configure(config)
    _ = try store.stop(scheduleId: config.scheduleId, nowMillis: fire + 1000, calendar: calendar)
    _ = try store.snooze(alarmId: "is", minutes: 5, nowMillis: fire + 2000)
    let next = try XCTUnwrap(store.stop(
      scheduleId: config.scheduleId, nowMillis: fire + 86_400_000 + 1000, calendar: calendar))
    XCTAssertEqual(next.event.firedAt, fire + 86_400_000)
    XCTAssertEqual(next.event.snoozeUsed, 0)
  }

  func testSnoozeDisabledAndWrongIdsCannotMutateSession() throws {
    var config = configuration("is")
    config.snoozeEnabled = false
    try store.configure(config)
    _ = try store.stop(scheduleId: config.scheduleId, nowMillis: fire + 1000)
    XCTAssertNil(try store.snooze(alarmId: "is", minutes: 5, nowMillis: fire + 2000))
    XCTAssertNil(try store.begin(alarmId: "other", nowMillis: fire + 2000))
    XCTAssertEqual(store.session(alarmId: "is")?.snoozeUsed, 0)
  }

  func testOldWatchdogCannotRestartCompletedOrNewerOccurrence() throws {
    let config = configuration("is")
    try store.configure(config)
    let stopped = try XCTUnwrap(store.stop(scheduleId: config.scheduleId, nowMillis: fire + 1000))
    let child = config.chainConfiguration(
      scheduleId: stopped.session.occurrenceId + "#w", fireAtMillis: fire + 31_000,
      originalFireAtMillis: fire)
    try store.configure(child)
    _ = try store.finish(alarmId: "is")
    XCTAssertNil(try store.stop(scheduleId: child.scheduleId, nowMillis: fire + 31_000))
  }

  func testFallbackCanStartMissionWhenPrimaryStopDidNotRun() throws {
    let config = configuration("is")
    try store.configure(config)
    var fallback = config.chainConfiguration(
      scheduleId: config.scheduleId + "#ladder0", fireAtMillis: fire + 300_000,
      originalFireAtMillis: fire)
    fallback.isFallback = true
    try store.configure(fallback)
    let stopped = try XCTUnwrap(store.stop(scheduleId: fallback.scheduleId, nowMillis: fire + 301_000))
    XCTAssertEqual(stopped.event.alarmId, "is")
    XCTAssertEqual(stopped.event.firedAt, fire)
    XCTAssertFalse(stopped.event.chainStopped)
  }

  func testLastAllowedRearmCanBeginMissionButNextStopEndsChain() throws {
    var config = configuration("is")
    config.maxRearms = 1
    try store.configure(config)
    _ = try store.stop(scheduleId: config.scheduleId, nowMillis: fire + 1000)
    XCTAssertNotNil(try store.begin(alarmId: "is", nowMillis: fire + 2000))
    let stopped = try XCTUnwrap(store.stop(scheduleId: config.scheduleId, nowMillis: fire + 3000))
    XCTAssertTrue(stopped.event.chainStopped)
  }

  func testWeeklyRefreshBeforeStopKeepsTheJustFiredOccurrence() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    var config = configuration("is")
    config.repeatWeekdays = [1, 2, 3, 4, 5, 6, 7]
    try store.configure(config)
    config.fireAtMillis = fire + 86_400_000
    try store.configure(config)
    let stopped = try XCTUnwrap(store.stop(scheduleId: config.scheduleId, nowMillis: fire + 1000, calendar: calendar))
    XCTAssertEqual(stopped.event.firedAt, fire)
  }

  func testRefreshRetainsRecentPrimaryButDiscardsCancelledFutureAndOldRecords() throws {
    let recent = configuration("is")
    let future = configuration("future", fireAt: fire + 86_400_000)
    let old = configuration("old", fireAt: fire - 7_200_000)
    for config in [recent, future, old] { try store.configure(config) }
    try store.retireConfigurations(keeping: [], nowMillis: fire + 1000)
    XCTAssertNotNil(try store.stop(scheduleId: recent.scheduleId, nowMillis: fire + 2000))
    XCTAssertNil(store.configurations[future.scheduleId])
    XCTAssertNil(store.configurations[old.scheduleId])
  }
}
