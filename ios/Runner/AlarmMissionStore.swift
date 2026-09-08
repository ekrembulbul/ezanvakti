import Foundation

struct AlarmMissionConfiguration: Codable, Equatable {
  var scheduleId: String
  var alarmId: String
  var label: String
  var fireAtMillis: Double
  var gated = false
  var snoozeEnabled = true
  var snoozeMinutes = 5
  var maxSnoozes: Int?
  var repeatWeekdays: [Int] = []
  var graceSeconds = 30
  var maxRearms = 40
  var chainDurationMillis = 3_600_000.0
  var missionTimeoutSeconds = 90
  var tintHex = ""
  var soundId = "default"
  var originalFireAtMillis: Double?
  var isFallback = false
  var presentationVersion: Int?
  var templateWeekdays: [Int]?

  var occurrenceId: String {
    "\(alarmId)#at\(Int64(originalFireAtMillis ?? fireAtMillis))"
  }

  var isAuxiliary: Bool { originalFireAtMillis != nil }

  func hasSameSchedule(as other: Self) -> Bool {
    var lhs = self
    var rhs = other
    if !repeatWeekdays.isEmpty, repeatWeekdays == other.repeatWeekdays {
      let calendar = Calendar.current
      let leftTime = calendar.dateComponents([.hour, .minute],
        from: Date(timeIntervalSince1970: fireAtMillis / 1000))
      let rightTime = calendar.dateComponents([.hour, .minute],
        from: Date(timeIntervalSince1970: other.fireAtMillis / 1000))
      guard leftTime == rightTime else { return false }
      lhs.fireAtMillis = 0
      rhs.fireAtMillis = 0
    }
    return lhs == rhs
  }

  func chainConfiguration(
    scheduleId: String, fireAtMillis: Double, originalFireAtMillis: Double
  ) -> Self {
    var copy = self
    copy.scheduleId = scheduleId
    copy.fireAtMillis = fireAtMillis
    copy.originalFireAtMillis = originalFireAtMillis
    copy.repeatWeekdays = []
    copy.isFallback = false
    return copy
  }

  /// Weekly AlarmKit records reuse a schedule id, but each day is a new mission.
  func occurrenceTime(at nowMillis: Double, calendar: Calendar) -> Double? {
    if let originalFireAtMillis { return originalFireAtMillis }
    if repeatWeekdays.isEmpty {
      return fireAtMillis <= nowMillis ? fireAtMillis : nil
    }
    let now = Date(timeIntervalSince1970: nowMillis / 1000)
    let first = Date(timeIntervalSince1970: fireAtMillis / 1000)
    let time = calendar.dateComponents([.hour, .minute], from: first)
    for offset in 0...7 {
      guard let day = calendar.date(byAdding: .day, value: -offset, to: now),
        let candidate = calendar.date(
          bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: day)
      else { continue }
      let isoDay = (calendar.component(.weekday, from: candidate) + 5) % 7 + 1
      let millis = candidate.timeIntervalSince1970 * 1000
      if repeatWeekdays.contains(isoDay), millis <= nowMillis {
        return millis
      }
    }
    return nil
  }
}

struct AlarmMissionSession: Codable {
  let configuration: AlarmMissionConfiguration
  let firedAtMillis: Double
  var pending = true
  var snoozeUsed = 0
  var rearmCount = 0
  var stoppedAtMillis: Double
  var deadlineMillis: Double?
  var snoozedUntilMillis: Double?
  var begun = false
  var timerScheduleId: String?
  var lastStopScheduleId: String?

  var occurrenceId: String { "\(configuration.alarmId)#at\(Int64(firedAtMillis))" }
  var chainDeadlineMillis: Double { firedAtMillis + configuration.chainDurationMillis }

  func canContinue(at now: Double) -> Bool {
    pending && (!configuration.gated ||
      (now < chainDeadlineMillis && rearmCount <= configuration.maxRearms))
  }

  var snapshot: [String: Any] {
    var value: [String: Any] = [
      "alarmId": configuration.alarmId, "firedAt": firedAtMillis,
      "stoppedAt": stoppedAtMillis, "snoozeUsed": snoozeUsed,
      "rearmCount": rearmCount, "pending": pending, "begun": begun,
    ]
    if begun, let deadlineMillis { value["deadlineAt"] = deadlineMillis }
    if let snoozedUntilMillis { value["snoozedUntil"] = snoozedUntilMillis }
    if configuration.gated { value["chainDeadlineAt"] = chainDeadlineMillis }
    return value
  }
}

struct AlarmMissionEvent: Codable {
  let alarmId: String
  let firedAt: Double
  let stoppedAt: Double
  let snoozeUsed: Int
  let rearmCount: Int
  let chainStopped: Bool

  var dictionary: [String: Any] {
    ["alarmId": alarmId, "firedAt": firedAt, "stoppedAt": stoppedAt,
     "snoozeUsed": snoozeUsed, "rearmCount": rearmCount, "chainStopped": chainStopped]
  }
}

struct AlarmMissionStop {
  let session: AlarmMissionSession
  let event: AlarmMissionEvent
  let rearmAtMillis: Double?
}

/// One persisted value keeps session changes and queued events together.
/// The handler serializes access with its AlarmKit operations.
final class AlarmMissionStore {
  private struct State: Codable {
    var configurations: [String: AlarmMissionConfiguration] = [:]
    var sessions: [String: AlarmMissionSession] = [:]
    var events: [AlarmMissionEvent] = []
    var enabledAlarmIds: Set<String>?
    var suppressedOccurrences: [String: Double]?
    var templates: [String: AlarmMissionConfiguration]?
  }
  private static let key = "ezanvakti_alarm_missions_v2"
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) { self.defaults = defaults }

  func validateReadable() throws {
    if let data = defaults.data(forKey: Self.key) {
      _ = try JSONDecoder().decode(State.self, from: data)
    }
  }

  private func read() -> State {
    guard let data = defaults.data(forKey: Self.key) else { return State() }
    do { return try JSONDecoder().decode(State.self, from: data) }
    catch {
      NSLog("alarm|mission_store|decode_failed|%@", AlarmJournal.errorCode(error))
      return State()
    }
  }

  private func save(_ state: State) throws {
    // A malformed persisted plan must never be replaced by an empty fallback.
    try validateReadable()
    defaults.set(try JSONEncoder().encode(state), forKey: Self.key)
  }

  var configurations: [String: AlarmMissionConfiguration] { read().configurations }

  func session(alarmId: String) -> AlarmMissionSession? { read().sessions[alarmId] }

  var pendingSessions: [AlarmMissionSession] {
    let state = read()
    return state.sessions.values.filter {
      $0.pending && (state.enabledAlarmIds?.contains($0.configuration.alarmId) ?? true)
    }.sorted {
      if $0.firedAtMillis != $1.firedAtMillis { return $0.firedAtMillis < $1.firedAtMillis }
      return $0.configuration.alarmId < $1.configuration.alarmId
    }
  }

  func setEnabledAlarmIds(_ ids: Set<String>) throws {
    var state = read()
    state.enabledAlarmIds = ids
    state.sessions = state.sessions.filter { ids.contains($0.key) }
    state.events.removeAll { !ids.contains($0.alarmId) }
    state.templates = state.templates?.filter { ids.contains($0.key) }
    try save(state)
  }

  func setTemplates(_ records: [AlarmMissionConfiguration]) throws {
    var state = read()
    var templates = state.templates ?? [:]
    var seen: Set<String> = []
    for record in records.filter({ !$0.isAuxiliary }).sorted(by: { $0.fireAtMillis < $1.fireAtMillis }) {
      if !seen.insert(record.alarmId).inserted { continue }
      if record.templateWeekdays?.isEmpty == false { templates[record.alarmId] = record }
      else { templates.removeValue(forKey: record.alarmId) }
    }
    state.templates = templates
    try save(state)
  }

  func template(alarmId: String) -> AlarmMissionConfiguration? { read().templates?[alarmId] }

  func hasFutureSuppression(alarmId: String, nowMillis: Double) -> Bool {
    (read().suppressedOccurrences ?? [:]).contains {
      $0.key.hasPrefix(alarmId + "#at") && $0.value > nowMillis
    }
  }

  func setSuppressedOccurrences(_ skips: [AlarmSuppression], nowMillis: Double) throws {
    var state = read()
    var kept = (state.suppressedOccurrences ?? [:]).filter {
      $0.value <= nowMillis && $0.value > nowMillis - 86_400_000
    }
    for skip in skips { kept[skip.occurrenceId] = skip.fireAtMillis }
    state.suppressedOccurrences = kept
    for (id, session) in state.sessions where kept[session.occurrenceId] != nil {
      state.sessions[id]?.pending = false
      state.sessions[id]?.deadlineMillis = nil
      state.sessions[id]?.snoozedUntilMillis = nil
      state.sessions[id]?.timerScheduleId = nil
    }
    try save(state)
  }

  func disableAlarm(_ id: String) throws {
    let state = read()
    let ids = state.enabledAlarmIds ??
      Set(state.configurations.values.map(\.alarmId)).union(state.sessions.keys)
    try setEnabledAlarmIds(ids.subtracting([id]))
  }

  func registerAlarm(_ id: String) throws {
    let state = read()
    let ids = state.enabledAlarmIds ??
      Set(state.configurations.values.map(\.alarmId)).union(state.sessions.keys)
    try setEnabledAlarmIds(ids.union([id]))
  }

  func restore(_ session: AlarmMissionSession) throws {
    var state = read()
    state.sessions[session.configuration.alarmId] = session
    try save(state)
  }

  func configure(_ configuration: AlarmMissionConfiguration) throws {
    var state = read()
    state.configurations[configuration.scheduleId] = configuration
    try save(state)
  }

  func removeConfigurations(_ ids: Set<String>) throws {
    var state = read()
    for id in ids { state.configurations.removeValue(forKey: id) }
    try save(state)
  }

  /// A cold-start refresh may run before a primary or auxiliary stop intent.
  func retireConfigurations(keeping ids: Set<String>, nowMillis: Double) throws {
    var state = read()
    state.configurations = state.configurations.filter { id, configuration in
      if ids.contains(id) { return true }
      guard state.enabledAlarmIds?.contains(configuration.alarmId) ?? true,
        let fire = configuration.occurrenceTime(at: nowMillis, calendar: .current),
        fire <= nowMillis
      else { return false }
      return nowMillis - fire < configuration.chainDurationMillis
    }
    try save(state)
  }

  func activeOccurrences(nowMillis: Double) -> Set<String> {
    Set(read().sessions.values.filter { session in
      guard session.canContinue(at: nowMillis) else { return false }
      return session.configuration.gated ||
        (session.snoozedUntilMillis ?? 0) > nowMillis ||
        session.stoppedAtMillis + 45_000 > nowMillis
    }.map(\.occurrenceId))
  }

  func stop(
    scheduleId: String, nowMillis: Double, calendar: Calendar = .current
  ) throws -> AlarmMissionStop? {
    var state = read()
    guard let configuration = state.configurations[scheduleId],
      state.enabledAlarmIds?.contains(configuration.alarmId) ?? true,
      configuration.originalFireAtMillis == nil || configuration.fireAtMillis <= nowMillis,
      let fire = configuration.occurrenceTime(at: nowMillis, calendar: calendar)
    else { return nil }
    if state.suppressedOccurrences?["\(configuration.alarmId)#at\(Int64(fire))"] != nil { return nil }
    let existing = state.sessions[configuration.alarmId]
    if let existing, existing.firedAtMillis > fire { return nil }
    let sameOccurrence = existing?.firedAtMillis == fire
    if sameOccurrence, existing?.lastStopScheduleId == scheduleId { return nil }
    // Old chain intents must never reactivate a completed or newer occurrence.
    if configuration.originalFireAtMillis != nil {
      let canStartFallback = configuration.isFallback &&
        (existing == nil || existing!.firedAtMillis < fire)
      if !canStartFallback && (!sameOccurrence || existing?.pending != true) { return nil }
      if sameOccurrence, let timerId = existing?.timerScheduleId, timerId != scheduleId {
        return nil
      }
    }
    if sameOccurrence && existing?.pending == false { return nil }
    var session = sameOccurrence ? existing! : AlarmMissionSession(
      configuration: configuration, firedAtMillis: fire, stoppedAtMillis: nowMillis)
    session.stoppedAtMillis = nowMillis
    session.lastStopScheduleId = scheduleId
    session.snoozedUntilMillis = nil
    session.begun = false
    session.pending = session.pending &&
      (session.configuration.gated || session.configuration.snoozeEnabled)
    let action = MissionStopPolicy.action(
      gated: session.configuration.gated, rearmCount: session.rearmCount,
      maxRearms: session.configuration.maxRearms, nowMillis: nowMillis,
      chainDeadlineMillis: session.chainDeadlineMillis)
    var rearmAt: Double?
    if action == .stopChain { session.pending = false }
    if action == .rearm {
      session.rearmCount += 1
      rearmAt = min(nowMillis + Double(session.configuration.graceSeconds * 1000), session.chainDeadlineMillis)
    }
    session.deadlineMillis = rearmAt
    let event = AlarmMissionEvent(
      alarmId: configuration.alarmId, firedAt: fire, stoppedAt: nowMillis,
      snoozeUsed: session.snoozeUsed, rearmCount: session.rearmCount,
      chainStopped: action == .stopChain)
    state.sessions[configuration.alarmId] = session
    state.events.append(event)
    if state.events.count > 64 { state.events.removeFirst(state.events.count - 64) }
    try save(state)
    return AlarmMissionStop(session: session, event: event, rearmAtMillis: rearmAt)
  }

  func consume(alarmId: String? = nil) throws -> [AlarmMissionEvent] {
    var state = read()
    guard let selected = alarmId ?? state.events.first?.alarmId else { return [] }
    let events = state.events.filter { $0.alarmId == selected }
    state.events.removeAll { $0.alarmId == selected }
    try save(state)
    return events
  }

  func begin(alarmId: String, nowMillis: Double) throws -> AlarmMissionSession? {
    var state = read()
    guard var session = state.sessions[alarmId], session.configuration.gated,
      session.canContinue(at: nowMillis), (session.snoozedUntilMillis ?? 0) <= nowMillis
    else { return nil }
    if session.begun, (session.deadlineMillis ?? 0) > nowMillis { return session }
    session.begun = true
    session.snoozedUntilMillis = nil
    session.deadlineMillis = min(
      nowMillis + Double(session.configuration.missionTimeoutSeconds * 1000), session.chainDeadlineMillis)
    state.sessions[alarmId] = session
    try save(state)
    return session
  }

  func snooze(alarmId: String, minutes: Int, nowMillis: Double) throws -> AlarmMissionSession? {
    var state = read()
    guard var session = state.sessions[alarmId], session.canContinue(at: nowMillis),
      session.configuration.snoozeEnabled, minutes == session.configuration.snoozeMinutes,
      minutes > 0
    else { return nil }
    if (session.snoozedUntilMillis ?? 0) > nowMillis { return session }
    let limit = session.configuration.maxSnoozes ?? (session.configuration.gated ? 5 : Int.max)
    guard session.snoozeUsed < limit else { return nil }
    let next = nowMillis + Double(minutes * 60_000)
    guard !session.configuration.gated || next < session.chainDeadlineMillis else { return nil }
    session.snoozeUsed += 1
    session.snoozedUntilMillis = next
    session.deadlineMillis = nil
    session.begun = false
    state.sessions[alarmId] = session
    try save(state)
    return session
  }

  @discardableResult
  func finish(alarmId: String) throws -> String? {
    var state = read()
    let occurrence = state.sessions[alarmId]?.occurrenceId
    state.sessions[alarmId]?.pending = false
    state.sessions[alarmId]?.deadlineMillis = nil
    state.sessions[alarmId]?.snoozedUntilMillis = nil
    state.sessions[alarmId]?.timerScheduleId = nil
    state.events.removeAll { $0.alarmId == alarmId }
    try save(state)
    return occurrence
  }

  func removeAlarm(_ alarmId: String) throws {
    var state = read()
    state.configurations = state.configurations.filter { $0.value.alarmId != alarmId }
    state.sessions.removeValue(forKey: alarmId)
    state.events.removeAll { $0.alarmId == alarmId }
    try save(state)
  }
}
