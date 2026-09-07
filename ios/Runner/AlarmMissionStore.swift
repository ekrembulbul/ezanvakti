import Foundation

struct AlarmMissionConfiguration: Codable {
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

  var occurrenceId: String { "\(configuration.alarmId)#at\(Int64(firedAtMillis))" }
  var chainDeadlineMillis: Double { firedAtMillis + configuration.chainDurationMillis }

  func canContinue(at now: Double) -> Bool {
    pending && (!configuration.gated ||
      (now < chainDeadlineMillis && rearmCount <= configuration.maxRearms))
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
  }
  private static let key = "ezanvakti_alarm_missions_v2"
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) { self.defaults = defaults }

  private func read() -> State {
    guard let data = defaults.data(forKey: Self.key) else { return State() }
    do { return try JSONDecoder().decode(State.self, from: data) }
    catch {
      NSLog("alarm|mission_store|decode_failed|%@", String(describing: error))
      return State()
    }
  }

  private func save(_ state: State) throws {
    defaults.set(try JSONEncoder().encode(state), forKey: Self.key)
  }

  var configurations: [String: AlarmMissionConfiguration] { read().configurations }

  func session(alarmId: String) -> AlarmMissionSession? { read().sessions[alarmId] }

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

  /// A cold-start refresh may run before the stop intent. Keep the recent
  /// primary configuration until that callback can identify its occurrence.
  func retireConfigurations(keeping ids: Set<String>, nowMillis: Double) throws {
    var state = read()
    state.configurations = state.configurations.filter { id, configuration in
      if ids.contains(id) { return true }
      guard configuration.originalFireAtMillis == nil,
        let fire = configuration.occurrenceTime(at: nowMillis, calendar: .current)
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
      configuration.originalFireAtMillis == nil || configuration.fireAtMillis <= nowMillis,
      let fire = configuration.occurrenceTime(at: nowMillis, calendar: calendar)
    else { return nil }
    let existing = state.sessions[configuration.alarmId]
    let sameOccurrence = existing?.firedAtMillis == fire
    // Old chain intents must never reactivate a completed or newer occurrence.
    if configuration.originalFireAtMillis != nil {
      let canStartFallback = configuration.isFallback &&
        (existing == nil || existing!.firedAtMillis < fire)
      if !canStartFallback && (!sameOccurrence || existing?.pending != true) { return nil }
    }
    if sameOccurrence && existing?.pending == false { return nil }
    var session = sameOccurrence ? existing! : AlarmMissionSession(
      configuration: configuration, firedAtMillis: fire, stoppedAtMillis: nowMillis)
    session.stoppedAtMillis = nowMillis
    session.snoozedUntilMillis = nil
    session.begun = false
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
    if session.begun { return session }
    session.begun = true
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
      minutes > 0, (session.snoozedUntilMillis ?? 0) <= nowMillis
    else { return nil }
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
