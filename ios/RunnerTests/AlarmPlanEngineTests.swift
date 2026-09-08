import XCTest
@testable import Runner

@MainActor
private final class FakeAlarmPlatform: AlarmPlatform {
  enum Failure: Error { case injected }
  var records: [UUID: AlarmMissionConfiguration] = [:]
  var states: [UUID: AlarmPlatformState] = [:]
  var failSchedules: Set<String> = []
  var failCancels: Set<UUID> = []
  var operations: [String] = []
  func alarms() throws -> [UUID: AlarmPlatformState] { states }
  func schedule(id: UUID, configuration: AlarmMissionConfiguration) async throws {
    operations.append("schedule:" + configuration.scheduleId)
    if failSchedules.contains(configuration.scheduleId) ||
      failSchedules.contains("*") { throw Failure.injected }
    records[id] = configuration
    states[id] = .scheduled
  }
  func cancel(id: UUID) throws {
    operations.append("cancel:" + (records[id]?.scheduleId ?? id.uuidString))
    if failCancels.contains(id) { throw Failure.injected }
    records.removeValue(forKey: id)
    states.removeValue(forKey: id)
  }
  func stop(id: UUID) throws { try cancel(id: id) }
}

private final class AlarmTestClock { var now = 1_800_000_000_000.0 }

final class AlarmPlanEngineTests: XCTestCase {
  @MainActor
  private func fixture() -> (AlarmPlanEngine, FakeAlarmPlatform, AlarmTestClock) {
    let domain = "alarm-plan-test-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: domain)!
    addTeardownBlock { defaults.removePersistentDomain(forName: domain) }
    let backend = FakeAlarmPlatform()
    let clock = AlarmTestClock()
    return (AlarmPlanEngine(platform: backend, defaults: defaults, clock: { clock.now }), backend, clock)
  }

  private func record(_ root: String, at time: Double) -> AlarmMissionConfiguration {
    AlarmMissionConfiguration(scheduleId: "\(root)#at\(Int64(time))",
      alarmId: root, label: root, fireAtMillis: time, gated: true,
      maxSnoozes: 1, presentationVersion: 2)
  }

  @MainActor
  func testUnchangedRefreshDoesNotCancelOrReschedule() async throws {
    let (engine, backend, clock) = fixture()
    let alarm = record("work", at: clock.now + 60_000)
    _ = try await engine.reconcile(records: [alarm], enabledAlarmIds: ["work"])
    backend.operations = []
    _ = try await engine.reconcile(records: [alarm], enabledAlarmIds: ["work"])
    XCTAssertTrue(backend.operations.isEmpty)
    XCTAssertEqual(backend.records.count, 1)
  }

  @MainActor
  func testFailedReplacementPreservesWorkingAlarmAndOtherRoot() async throws {
    let (engine, backend, clock) = fixture()
    let old = record("work", at: clock.now + 60_000)
    let other = record("sunrise", at: clock.now + 90_000)
    _ = try await engine.reconcile(records: [old, other], enabledAlarmIds: ["work", "sunrise"])
    let replacement = record("work", at: clock.now + 120_000)
    backend.failSchedules = [replacement.scheduleId]
    let failures = try await engine.reconcile(records: [replacement, other],
      enabledAlarmIds: ["work", "sunrise"])
    XCTAssertNotNil(failures["work"])
    XCTAssertEqual(Set(backend.records.values.map(\.scheduleId)), [old.scheduleId, other.scheduleId])
  }

  @MainActor
  func testFailedPrimaryDoesNotLeaveFallbackAsTheOnlyAlarm() async throws {
    let (engine, backend, clock) = fixture()
    let primary = record("work", at: clock.now + 60_000)
    var fallback = primary.chainConfiguration(scheduleId: primary.scheduleId + "#ladder0",
      fireAtMillis: primary.fireAtMillis + 300_000, originalFireAtMillis: primary.fireAtMillis)
    fallback.isFallback = true
    backend.failSchedules = [primary.scheduleId]
    _ = try await engine.reconcile(records: [primary, fallback], enabledAlarmIds: ["work"])
    XCTAssertTrue(backend.records.isEmpty)
  }

  @MainActor
  func testMissingPrayerDataPreservesItsRootWhileDeletingAnother() async throws {
    let (engine, backend, clock) = fixture()
    let kept = record("sunrise", at: clock.now + 60_000)
    let deleted = record("copy", at: clock.now + 90_000)
    _ = try await engine.reconcile(records: [kept, deleted], enabledAlarmIds: ["sunrise", "copy"])
    _ = try await engine.reconcile(records: [], enabledAlarmIds: ["sunrise"], preserveAlarmIds: ["sunrise"])
    XCTAssertEqual(backend.records.values.map(\.alarmId), ["sunrise"])
  }

  @MainActor
  func testExplicitDeleteRemovesActiveChainAndRejectsLateStop() async throws {
    let (engine, backend, clock) = fixture()
    let primary = record("copy", at: clock.now + 1000)
    _ = try await engine.reconcile(records: [primary], enabledAlarmIds: ["copy"])
    clock.now += 1001
    _ = try await engine.stop(scheduleId: primary.scheduleId)
    XCTAssertEqual(try engine.snapshots().count, 1)
    try engine.cancelAlarm("copy")
    XCTAssertTrue(backend.records.isEmpty)
    XCTAssertTrue(try engine.snapshots().isEmpty)
    let lateStop = try await engine.stop(scheduleId: primary.scheduleId)
    XCTAssertNil(lateStop)
  }

  @MainActor
  func testRefreshKeepsAnAlarmAtTheDeliveryBoundary() async throws {
    let (engine, backend, clock) = fixture()
    let primary = record("sunrise", at: clock.now + 1000)
    _ = try await engine.reconcile(records: [primary], enabledAlarmIds: ["sunrise"])
    clock.now += 500
    _ = try await engine.reconcile(records: [], enabledAlarmIds: ["sunrise"])
    XCTAssertEqual(backend.records.count, 1)
  }

  @MainActor
  func testRearmFailureKeepsAllExistingFallbacks() async throws {
    let (engine, backend, clock) = fixture()
    let primary = record("work", at: clock.now + 1000)
    var records = [primary]
    for i in 0..<3 {
      var child = primary.chainConfiguration(scheduleId: primary.scheduleId + "#ladder\(i)",
        fireAtMillis: primary.fireAtMillis + Double((i + 1) * 300_000),
        originalFireAtMillis: primary.fireAtMillis)
      child.isFallback = true
      records.append(child)
    }
    _ = try await engine.reconcile(records: records, enabledAlarmIds: ["work"])
    clock.now += 1001
    backend.failSchedules = ["*"]
    _ = try await engine.stop(scheduleId: primary.scheduleId)
    XCTAssertEqual(backend.records.values.filter(\.isFallback).count, 3)
    XCTAssertTrue(engine.missions.session(alarmId: "work")!.pending)
    XCTAssertTrue(engine.journal.entries.contains { $0.operation == "stop_rearm" && $0.result == "failed" })
  }

  @MainActor
  func testSnoozeInstallsNewTimerBeforeRetiringPreviousOne() async throws {
    let (engine, backend, clock) = fixture()
    let primary = record("work", at: clock.now + 1000)
    _ = try await engine.reconcile(records: [primary], enabledAlarmIds: ["work"])
    clock.now += 1001
    _ = try await engine.stop(scheduleId: primary.scheduleId)
    backend.operations = []
    try await engine.snooze("work", minutes: 5, expectedFireMillis: primary.fireAtMillis)
    XCTAssertTrue(backend.operations.first!.hasPrefix("schedule:"))
    XCTAssertTrue(backend.operations.dropFirst().contains { $0.hasPrefix("cancel:") })
    let session = engine.missions.session(alarmId: "work")!
    XCTAssertEqual(session.snoozeUsed, 1)
    let timer = session.timerScheduleId!
    XCTAssertEqual(engine.missions.configurations[timer]?.fireAtMillis, clock.now + 300_000)
  }

  @MainActor
  func testCleanupRetryDoesNotSpendAnotherSnooze() async throws {
    let (engine, backend, clock) = fixture()
    let primary = record("work", at: clock.now + 1000)
    _ = try await engine.reconcile(records: [primary], enabledAlarmIds: ["work"])
    clock.now += 1001
    _ = try await engine.stop(scheduleId: primary.scheduleId)
    let oldTimer = engine.missions.session(alarmId: "work")!.timerScheduleId!
    backend.failCancels = [engine.mapping[oldTimer]!]
    do { try await engine.snooze("work", minutes: 5); XCTFail("Injected cleanup failure") }
    catch {}
    let accepted = engine.missions.session(alarmId: "work")!
    XCTAssertEqual(accepted.snoozeUsed, 1)
    XCTAssertNotEqual(accepted.timerScheduleId, oldTimer)
    backend.failCancels = []
    try await engine.snooze("work", minutes: 5)
    XCTAssertEqual(engine.missions.session(alarmId: "work")?.snoozeUsed, 1)
    XCTAssertNil(engine.mapping[oldTimer])
  }

  @MainActor
  func testOldOccurrenceCannotCompleteNewSession() async throws {
    let (engine, _, clock) = fixture()
    let primary = record("work", at: clock.now + 1000)
    _ = try await engine.reconcile(records: [primary], enabledAlarmIds: ["work"])
    clock.now += 1001
    _ = try await engine.stop(scheduleId: primary.scheduleId)
    XCTAssertThrowsError(try engine.complete("work", expectedFireMillis: primary.fireAtMillis - 86_400_000))
    XCTAssertTrue(engine.missions.session(alarmId: "work")!.pending)
  }

  @MainActor
  func testExplicitSkipOverridesDeliveryGuardAndIgnoresLateStop() async throws {
    let (engine, backend, clock) = fixture()
    let primary = record("work", at: clock.now + 500)
    _ = try await engine.reconcile(records: [primary], enabledAlarmIds: ["work"])
    _ = try await engine.reconcile(records: [], enabledAlarmIds: ["work"],
      skips: [AlarmSuppression(alarmId: "work", fireAtMillis: primary.fireAtMillis)])
    XCTAssertTrue(backend.records.isEmpty)
    clock.now += 1000
    let event = try await engine.stop(scheduleId: primary.scheduleId)
    XCTAssertNil(event)
    XCTAssertTrue(try engine.snapshots().isEmpty)
  }

  @MainActor
  func testStoppingDatedFixedAlarmRestoresWeeklyTemplateAfterSkip() async throws {
    let (engine, backend, clock) = fixture()
    var first = record("work", at: clock.now + 60_000)
    first.templateWeekdays = [1, 2, 3, 4, 5, 6, 7]
    first.gated = false
    first.snoozeEnabled = false
    var later = first
    later.fireAtMillis += 86_400_000
    later.scheduleId = "work#at\(Int64(later.fireAtMillis))"
    _ = try await engine.reconcile(records: [first, later], enabledAlarmIds: ["work"],
      skips: [AlarmSuppression(alarmId: "work", fireAtMillis: clock.now - 86_400_000)])
    clock.now = first.fireAtMillis + 1000
    _ = try await engine.stop(scheduleId: first.scheduleId)
    XCTAssertEqual(backend.records[engine.mapping["work"]!]?.repeatWeekdays, first.templateWeekdays)
    XCTAssertNil(engine.mapping[later.scheduleId])
    XCTAssertTrue(try engine.snapshots().isEmpty)
  }

  @MainActor
  func testRefreshKeepsLegacySnoozeWithoutTimerId() async throws {
    let (engine, backend, clock) = fixture()
    let primary = record("work", at: clock.now + 1000)
    _ = try await engine.reconcile(records: [primary], enabledAlarmIds: ["work"])
    clock.now += 1001
    _ = try engine.missions.stop(scheduleId: primary.scheduleId, nowMillis: clock.now)
    let session = try XCTUnwrap(engine.missions.snooze(alarmId: "work", minutes: 5, nowMillis: clock.now))
    let legacy = primary.chainConfiguration(scheduleId: session.occurrenceId + "#w",
      fireAtMillis: session.snoozedUntilMillis!, originalFireAtMillis: session.firedAtMillis)
    try await engine.upsert(legacy)
    _ = try await engine.reconcile(records: [], enabledAlarmIds: ["work"])
    XCTAssertNotNil(backend.records[engine.mapping[legacy.scheduleId]!])
  }

  @MainActor
  func testRemovingFutureSkipRestoresOccurrenceButPastSkipSurvivesRefresh() async throws {
    let (engine, _, clock) = fixture()
    let past = record("work", at: clock.now - 1000)
    let future = record("work", at: clock.now + 60_000)
    try engine.missions.configure(past)
    _ = try await engine.reconcile(records: [], enabledAlarmIds: ["work"],
      skips: [AlarmSuppression(alarmId: "work", fireAtMillis: past.fireAtMillis),
        AlarmSuppression(alarmId: "work", fireAtMillis: future.fireAtMillis)])
    _ = try await engine.reconcile(records: [future], enabledAlarmIds: ["work"])
    let ignored = try await engine.stop(scheduleId: past.scheduleId)
    XCTAssertNil(ignored)
    clock.now = future.fireAtMillis + 100
    let accepted = try await engine.stop(scheduleId: future.scheduleId)
    XCTAssertNotNil(accepted)
  }

  @MainActor
  func testCorruptUuidMappingDoesNotCancelExistingOsAlarm() async throws {
    let domain = "alarm-map-test-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let backend = FakeAlarmPlatform()
    let id = UUID()
    backend.states[id] = .scheduled
    defaults.set(["work": "invalid-uuid"], forKey: "ezanvakti_alarm_uuid_map")
    let engine = AlarmPlanEngine(platform: backend, defaults: defaults)
    do {
      _ = try await engine.reconcile(records: [], enabledAlarmIds: ["work"],
        preserveAlarmIds: ["work"])
      XCTFail("Corrupt mapping must be reported")
    } catch {}
    XCTAssertEqual(backend.states[id], .scheduled)
  }

  @MainActor
  func testPartialCacheKeepsMissingPeriodUpdatesKnownPeriodAndHonorsSkip() async throws {
    let (engine, backend, clock) = fixture()
    let missing = record("sun", at: clock.now + 60_000)
    let known = record("sun", at: clock.now + 90_000)
    _ = try await engine.reconcile(records: [missing, known], enabledAlarmIds: ["sun"])
    let changed = record("sun", at: clock.now + 120_000)
    let period = AlarmPreservedPeriod(alarmId: "sun", fromMillis: clock.now, untilMillis: clock.now + 75_000)
    _ = try await engine.reconcile(records: [changed], enabledAlarmIds: ["sun"], preservedPeriods: [period])
    XCTAssertEqual(Set(backend.records.values.map(\.scheduleId)), [missing.scheduleId, changed.scheduleId])
    _ = try await engine.reconcile(records: [changed], enabledAlarmIds: ["sun"],
      skips: [AlarmSuppression(alarmId: "sun", fireAtMillis: missing.fireAtMillis)],
      preservedPeriods: [period])
    XCTAssertEqual(backend.records.values.map(\.scheduleId), [changed.scheduleId])
  }
}
