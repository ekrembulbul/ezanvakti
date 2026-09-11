import Foundation

struct AlarmPreservedPeriod {
  let alarmId: String
  let fromMillis: Double
  let untilMillis: Double
  func matches(_ record: AlarmMissionConfiguration, now: Double) -> Bool {
    let fire = record.originalFireAtMillis ?? record.fireAtMillis
    return record.alarmId == alarmId && record.repeatWeekdays.isEmpty &&
      fire > now && fromMillis <= fire && fire < untilMillis
  }
}

struct AlarmSuppression {
  let alarmId: String
  let fireAtMillis: Double
  var occurrenceId: String { "\(alarmId)#at\(Int64(fireAtMillis))" }

  func matches(_ record: AlarmMissionConfiguration) -> Bool {
    guard record.alarmId == alarmId else { return false }
    if record.repeatWeekdays.isEmpty { return record.occurrenceId == occurrenceId }
    let calendar = Calendar.current
    let date = Date(timeIntervalSince1970: fireAtMillis / 1000)
    let template = Date(timeIntervalSince1970: record.fireAtMillis / 1000)
    let isoDay = (calendar.component(.weekday, from: date) + 5) % 7 + 1
    return record.repeatWeekdays.contains(isoDay) &&
      calendar.dateComponents([.hour, .minute], from: date) ==
      calendar.dateComponents([.hour, .minute], from: template)
  }
}

enum AlarmPlatformState {
  case scheduled, alerting, countdown, paused, unknown
  var protectsDelivery: Bool { self != .scheduled }
}

@MainActor
protocol AlarmPlatform {
  func alarms() throws -> [UUID: AlarmPlatformState]
  func schedule(id: UUID, configuration: AlarmMissionConfiguration) async throws
  func cancel(id: UUID) throws
  func stop(id: UUID) throws
}

/// Owns reconciliation and mission transitions. The bridge serializes calls.
@MainActor
final class AlarmPlanEngine {
  enum EngineError: Error { case invalidTime, invalidState, staleOccurrence, unavailable }
  private static let mapKey = "ezanvakti_alarm_uuid_map"
  // Avoid cancelling a record while the OS is changing it to alerting.
  private static let deliveryGuardMillis = 1000.0
  let missions: AlarmMissionStore
  let journal: AlarmJournal
  private let platform: AlarmPlatform
  private let defaults: UserDefaults
  private let clock: () -> Double
  private var observedStates: [UUID: AlarmPlatformState] = [:]

  init(platform: AlarmPlatform, defaults: UserDefaults = .standard,
    clock: @escaping () -> Double = { Date().timeIntervalSince1970 * 1000 }) {
    self.platform = platform
    self.defaults = defaults
    self.clock = clock
    missions = AlarmMissionStore(defaults: defaults)
    journal = AlarmJournal(defaults: defaults)
  }

  private func validateState() throws {
    try missions.validateReadable()
    guard defaults.object(forKey: Self.mapKey) != nil else { return }
    guard let raw = defaults.dictionary(forKey: Self.mapKey) as? [String: String],
      raw.values.allSatisfy({ UUID(uuidString: $0) != nil }),
      Set(raw.values.compactMap(UUID.init(uuidString:))).count == raw.count
    else { throw EngineError.invalidState }
  }

  var mapping: [String: UUID] {
    let raw = defaults.dictionary(forKey: Self.mapKey) as? [String: String] ?? [:]
    return raw.compactMapValues(UUID.init(uuidString:))
  }

  private func setMapping(_ value: [String: UUID]) {
    defaults.set(value.mapValues(\.uuidString), forKey: Self.mapKey)
  }

  private func uuid(for id: String) -> UUID {
    if let existing = mapping[id] { return existing }
    var value = mapping
    let uuid = UUID()
    value[id] = uuid
    setMapping(value)
    return uuid
  }

  func snapshots() throws -> [[String: Any]] {
    try validateState()
    return missions.pendingSessions.map(\.snapshot)
  }

  func reconcile(
    records: [AlarmMissionConfiguration], enabledAlarmIds: Set<String>,
    preserveAlarmIds: Set<String> = [], skips: [AlarmSuppression] = [],
    preservedPeriods: [AlarmPreservedPeriod] = []
  ) async throws -> [String: String] {
    try validateState()
    try missions.setEnabledAlarmIds(enabledAlarmIds)
    try missions.setSuppressedOccurrences(skips, nowMillis: clock())
    try missions.setTemplates(records)
    var desired: Set<String> = []
    var acceptedSources: Set<String> = []
    var failures: [String: String] = [:]
    let firstByRoot = Dictionary(grouping: records.filter { !$0.isAuxiliary }, by: \.alarmId)
      .mapValues { $0.map(\.fireAtMillis).min()! }
    func priority(_ record: AlarmMissionConfiguration) -> Int {
      record.isAuxiliary ? 2 : (firstByRoot[record.alarmId] == record.fireAtMillis ? 0 : 1)
    }
    let ordered = records.sorted {
      if priority($0) != priority($1) { return priority($0) < priority($1) }
      if $0.fireAtMillis != $1.fireAtMillis { return $0.fireAtMillis < $1.fireAtMillis }
      return $0.scheduleId < $1.scheduleId
    }
    for record in ordered where enabledAlarmIds.contains(record.alarmId) {
      if record.isFallback {
        guard acceptedSources.contains(record.occurrenceId) else { continue }
        if let session = missions.session(alarmId: record.alarmId),
          session.occurrenceId == record.occurrenceId,
          !session.pending || session.timerScheduleId != nil { continue }
      }
      desired.insert(record.scheduleId)
      do {
        try await upsert(record)
        if !record.isAuxiliary { acceptedSources.insert(record.occurrenceId) }
      }
      catch {
        failures[record.alarmId] = AlarmJournal.errorCode(error)
        journal.record("schedule", at: clock(), configuration: record, result: "failed", error: error)
      }
    }

    try stopStaleAlerts()

    for (id, uuid) in mapping {
      let record = missions.configurations[id]
      let root = record?.alarmId ?? String(id.split(separator: "#", maxSplits: 1).first ?? "")
      let enabled = enabledAlarmIds.contains(root)
      if enabled {
        if desired.contains(id) { continue }
        let explicitlySkipped = record.map { record in skips.contains { $0.matches(record) } } ?? false
        if !explicitlySkipped {
          if preserveAlarmIds.contains(root) || failures[root] != nil { continue }
          if let record, preservedPeriods.contains(where: { $0.matches(record, now: clock()) }) { continue }
          if let record, try protectedFromRefresh(record, uuid: uuid) { continue }
        }
      }
      do { try cancelRecord(id, retainConfiguration: enabled) }
      catch {
        failures[root] = "cancel_failed"
        journal.record("cancel", at: clock(), configuration: record,
          alarmId: root, scheduleId: id, result: "failed", error: error)
      }
    }

    // The old unawaited scheduler could leave OS entries outside its id map.
    let known = Set(mapping.values)
    for (id, state) in try platform.alarms() where !known.contains(id) {
      if state == .alerting { continue }
      do {
        try platform.cancel(id: id)
        journal.record("retire_orphan", at: clock(), scheduleId: id.uuidString)
      } catch {
        failures["_orphan"] = "cancel_failed"
        journal.record("retire_orphan", at: clock(), scheduleId: id.uuidString,
          result: "failed", error: error)
      }
    }
    try missions.retireConfigurations(keeping: Set(mapping.keys), nowMillis: clock())
    journal.record("reconcile", at: clock(), result: failures.isEmpty ? "ok" : "partial")
    return failures
  }

  private func protectedFromRefresh(_ record: AlarmMissionConfiguration, uuid: UUID) throws -> Bool {
    let state = try platform.alarms()[uuid]
    if state?.protectsDelivery == true { return true }
    let now = clock()
    if record.isAuxiliary {
      if let session = missions.session(alarmId: record.alarmId),
        session.occurrenceId == record.occurrenceId {
        guard session.canContinue(at: now) else { return false }
        if let timerId = session.timerScheduleId { return record.scheduleId == timerId }
        return record.isFallback ||
          record.fireAtMillis == (session.snoozedUntilMillis ?? session.deadlineMillis)
      }
      let fire = record.originalFireAtMillis ?? record.fireAtMillis
      return fire <= now && now < fire + record.chainDurationMillis
    }
    return record.repeatWeekdays.isEmpty &&
      record.fireAtMillis <= now + Self.deliveryGuardMillis &&
      now < record.fireAtMillis + record.chainDurationMillis
  }

  func upsert(_ record: AlarmMissionConfiguration) async throws {
    try validateState()
    var retiring: UUID?
    if let id = mapping[record.scheduleId], let state = try platform.alarms()[id] {
      if state.protectsDelivery { return }
      if let old = missions.configurations[record.scheduleId], old.hasSameSchedule(as: record) { return }
      // AlarmKit does not update an existing id: the second schedule fails with
      // invalidInput ("duplicate ID", device archive 2026-09-10). The change is
      // registered under a fresh id first, then the old record is retired, so a
      // failed replacement leaves the working alarm in place.
      retiring = id
    }
    guard record.fireAtMillis.isFinite,
      !record.repeatWeekdays.isEmpty || record.fireAtMillis > clock()
    else { throw EngineError.invalidTime }
    journal.record("schedule_requested", at: clock(), configuration: record)
    let id = retiring == nil ? uuid(for: record.scheduleId) : UUID()
    try await platform.schedule(id: id, configuration: record)
    if let retiring {
      var values = mapping
      values[record.scheduleId] = id
      setMapping(values)
      do { try platform.cancel(id: retiring) }
      catch {
        // The mapping already points at the new id; the old record is now an
        // orphan and the next reconcile retries its removal.
        journal.record("retire_replaced", at: clock(), configuration: record,
          scheduleId: record.scheduleId, result: "failed", error: error)
      }
    }
    try missions.configure(record)
    journal.record("scheduled", at: clock(), configuration: record)
  }

  func cancelAlarm(_ alarmId: String) throws {
    try validateState()
    // Durable intent precedes SDK cleanup; delayed callbacks cannot rearm it.
    try missions.disableAlarm(alarmId)
    let records = missions.configurations
    var failure: Error?
    for id in mapping.keys where id == alarmId ||
      records[id]?.alarmId == alarmId || id.hasPrefix(alarmId + "#") {
      do { try cancelRecord(id) }
      catch {
        failure = failure ?? error
        journal.record("delete", at: clock(), configuration: records[id],
          alarmId: alarmId, scheduleId: id, result: "failed", error: error)
      }
    }
    if let failure { throw failure }
    try missions.removeAlarm(alarmId)
    journal.record("delete", at: clock(), alarmId: alarmId)
  }

  func scheduleLegacy(_ records: [AlarmMissionConfiguration]) async throws {
    try validateState()
    for record in records {
      try missions.registerAlarm(record.alarmId)
      try await upsert(record)
    }
  }

  func cancelAllLegacy() throws {
    try validateState()
    for (id, uuid) in mapping {
      if let record = missions.configurations[id],
        try protectedFromRefresh(record, uuid: uuid) { continue }
      try cancelRecord(id, retainConfiguration: true)
    }
    try missions.retireConfigurations(keeping: Set(mapping.keys), nowMillis: clock())
  }

  private func cancelRecord(_ id: String, retainConfiguration: Bool = false) throws {
    let record = missions.configurations[id]
    if let uuid = mapping[id], try platform.alarms()[uuid] != nil {
      try platform.cancel(id: uuid)
    }
    var values = mapping
    values.removeValue(forKey: id)
    setMapping(values)
    if !retainConfiguration { try missions.removeConfigurations([id]) }
    journal.record("cancelled", at: clock(), configuration: record, scheduleId: id)
  }

  private func cancelAuxiliaries(_ occurrenceId: String, except keptId: String? = nil) throws {
    var failure: Error?
    for id in MissionChainKeys.select(alarmId: occurrenceId, from: Array(mapping.keys)) where id != keptId {
      do { try cancelRecord(id, retainConfiguration: true) }
      catch {
        failure = failure ?? error
        journal.record("cleanup", at: clock(), configuration: missions.configurations[id],
          scheduleId: id, result: "failed", error: error)
      }
    }
    if let failure { throw failure }
  }

  @discardableResult
  func stop(scheduleId: String) async throws -> AlarmMissionEvent? {
    try validateState()
    guard let stopped = try missions.stop(scheduleId: scheduleId, nowMillis: clock()) else {
      journal.record("stop_ignored", at: clock(), scheduleId: scheduleId)
      return nil
    }
    journal.record("stopped", at: clock(), configuration: missions.configurations[scheduleId])
    stopAlertingSiblings(alarmId: stopped.session.configuration.alarmId, except: scheduleId)
    if let next = stopped.rearmAtMillis {
      do { try await rearm(stopped.session, at: next) }
      catch {
        // The stop remains durable; existing fallbacks have not been discarded.
        journal.record("stop_rearm", at: clock(), configuration: stopped.session.configuration,
          result: "failed", error: error)
      }
    } else if stopped.event.chainStopped {
      try cancelAuxiliaries(stopped.session.occurrenceId)
    }
    await restoreWeeklyTemplateIfReady(stopped.session.configuration.alarmId)
    return stopped.event
  }

  private func restoreWeeklyTemplateIfReady(_ root: String) async {
    guard var template = missions.template(alarmId: root),
      let weekdays = template.templateWeekdays, !weekdays.isEmpty,
      !missions.hasFutureSuppression(alarmId: root, nowMillis: clock())
    else { return }
    template.scheduleId = root
    template.repeatWeekdays = weekdays
    template.originalFireAtMillis = nil
    template.isFallback = false
    do {
      try await upsert(template)
      for (id, record) in missions.configurations where record.alarmId == root && id != root {
        let futurePrimary = !record.isAuxiliary && record.repeatWeekdays.isEmpty && record.fireAtMillis > clock()
        let futureAuxiliary = record.isAuxiliary && (record.originalFireAtMillis ?? 0) > clock()
        if futurePrimary || futureAuxiliary { try cancelRecord(id) }
      }
    } catch {
      journal.record("restore_weekly", at: clock(), alarmId: root, result: "failed", error: error)
    }
  }

  private func matchingSession(_ alarmId: String, expectedFireMillis: Double?) throws -> AlarmMissionSession? {
    try validateState()
    let session = missions.session(alarmId: alarmId)
    if let expectedFireMillis, let session, session.firedAtMillis != expectedFireMillis {
      throw EngineError.staleOccurrence
    }
    return session
  }

  func begin(_ alarmId: String, expectedFireMillis: Double? = nil) async throws {
    let previous = try matchingSession(alarmId, expectedFireMillis: expectedFireMillis)
    guard let next = try missions.begin(alarmId: alarmId, nowMillis: clock()),
      let deadline = next.deadlineMillis else { throw EngineError.unavailable }
    try await transitionTimer(next, at: deadline, previous: previous, operation: "begin")
  }

  func snooze(_ alarmId: String, minutes: Int, expectedFireMillis: Double? = nil) async throws {
    let previous = try matchingSession(alarmId, expectedFireMillis: expectedFireMillis)
    guard let next = try missions.snooze(alarmId: alarmId, minutes: minutes, nowMillis: clock()),
      let deadline = next.snoozedUntilMillis else { throw EngineError.unavailable }
    try await transitionTimer(next, at: deadline, previous: previous, operation: "snooze")
  }

  private func transitionTimer(_ next: AlarmMissionSession, at deadline: Double,
    previous: AlarmMissionSession?, operation: String) async throws {
    do {
      try await rearm(next, at: deadline)
      journal.record(operation, at: clock(), configuration: next.configuration)
    } catch {
      // If a new timer was accepted, retain its matching state even when
      // retiring an old timer failed. Retry will only finish that cleanup.
      if missions.session(alarmId: next.configuration.alarmId)?.timerScheduleId == previous?.timerScheduleId,
        let previous { try missions.restore(previous) }
      journal.record(operation, at: clock(), configuration: next.configuration, result: "failed", error: error)
      throw error
    }
  }

  private func rearm(_ session: AlarmMissionSession, at deadline: Double) async throws {
    guard deadline.isFinite, deadline > clock() else { throw EngineError.invalidTime }
    var updated = session
    let id: String
    if let existing = session.timerScheduleId,
      missions.configurations[existing]?.fireAtMillis == deadline,
      let uuid = mapping[existing], try platform.alarms()[uuid] != nil {
      id = existing
    } else {
      id = session.occurrenceId + "#w" + UUID().uuidString
      let record = session.configuration.chainConfiguration(
        scheduleId: id, fireAtMillis: deadline, originalFireAtMillis: session.firedAtMillis)
      try await upsert(record)
      updated.timerScheduleId = id
      try missions.restore(updated)
    }
    try cancelAuxiliaries(session.occurrenceId, except: id)
  }

  func complete(_ alarmId: String, expectedFireMillis: Double? = nil, aborted: Bool = false) throws {
    let session = try matchingSession(alarmId, expectedFireMillis: expectedFireMillis)
    guard let session else { return }
    try missions.finish(alarmId: alarmId)
    try cancelAuxiliaries(session.occurrenceId)
    stopAlertingSiblings(alarmId: alarmId, except: nil)
    journal.record(aborted ? "abort" : "complete", at: clock(), configuration: session.configuration)
  }

  /// Aynı alarmın OS'ta hâlâ çalan diğer kayıtlarını susturur.
  ///
  /// 11 Eylül sabahı: cihaz uyanmayınca ana kayıt geç tetiklenip +5 yedeğiyle
  /// üst üste çaldı; kullanıcı üstteki yedeği durdurdu, ana kayıt kilit
  /// ekranında görünmeden "alerting" kaldı ve iOS onu 45 dakika sonra
  /// yeniden gösterdi. Bir alarm aynı anda tek çalış için çalar; biri
  /// durdurulduysa diğerleri kopyadır.
  private func stopAlertingSiblings(alarmId: String, except keptId: String?) {
    let states = (try? platform.alarms()) ?? [:]
    for (id, uuid) in mapping where id != keptId && states[uuid] == .alerting {
      guard let record = missions.configurations[id], record.alarmId == alarmId else { continue }
      do {
        try platform.stop(id: uuid)
        journal.record("stop_sibling", at: clock(), configuration: record, scheduleId: id)
      } catch {
        journal.record("stop_sibling", at: clock(), configuration: record,
          scheduleId: id, result: "failed", error: error)
      }
    }
  }

  /// Zinciri bitmiş ya da daha yeni bir çalışla geride kalmış alarmın OS'ta
  /// "çalıyor" duran kaydı. Kimse durdurmadıysa iOS onu ileride yeniden
  /// gösteriyor; uzlaştırma bunu susturur. Henüz kimsenin dokunmadığı bir
  /// çalış (oturumu yok) ya da zinciri süren çalış korunur.
  private func stopStaleAlerts() throws {
    let now = clock()
    let states = try platform.alarms()
    for (id, uuid) in mapping where states[uuid] == .alerting {
      guard let record = missions.configurations[id],
        let session = missions.session(alarmId: record.alarmId) else { continue }
      let fire = record.originalFireAtMillis ?? record.fireAtMillis
      let olderOccurrence = record.repeatWeekdays.isEmpty && fire < session.firedAtMillis
      let finished = !session.pending || !session.canContinue(at: now)
      guard finished || olderOccurrence else { continue }
      do {
        try platform.stop(id: uuid)
        journal.record("stop_stale", at: now, configuration: record, scheduleId: id)
      } catch {
        journal.record("stop_stale", at: now, configuration: record,
          scheduleId: id, result: "failed", error: error)
      }
    }
  }

  func observe(_ states: [UUID: AlarmPlatformState]) {
    do { try validateState() }
    catch {
      journal.record("observe", at: clock(), result: "invalid_state", error: error)
      return
    }
    let byUuid = Dictionary(uniqueKeysWithValues: mapping.map { ($0.value, $0.key) })
    for (uuid, state) in states where observedStates[uuid] != state {
      guard let id = byUuid[uuid] else { continue }
      journal.record("observed_state", at: clock(), configuration: missions.configurations[id],
        scheduleId: id, result: String(describing: state))
    }
    observedStates = states
  }
}
