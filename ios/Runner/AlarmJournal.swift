import Foundation

struct AlarmJournalEntry: Codable {
  let timeMillis: Double
  let operation: String
  let alarmId: String?
  let scheduleId: String?
  let expectedMillis: Double?
  let result: String
  let errorCode: String?
}

/// Bounded diagnostics contain opaque ids and timestamps, never alarm labels.
final class AlarmJournal {
  private static let key = "ezanvakti_alarm_journal_v1"
  private let defaults: UserDefaults
  private let limit: Int
  private let retentionMillis: Double

  init(defaults: UserDefaults = .standard, limit: Int = 2048,
    retentionMillis: Double = 7 * 86_400_000) {
    self.defaults = defaults
    self.limit = max(1, limit)
    self.retentionMillis = retentionMillis
  }

  var entries: [AlarmJournalEntry] {
    guard let data = defaults.data(forKey: Self.key) else { return [] }
    do { return try JSONDecoder().decode([AlarmJournalEntry].self, from: data) }
    catch {
      NSLog("alarm|journal|decode_failed")
      return []
    }
  }

  func record(_ operation: String, at now: Double,
    configuration: AlarmMissionConfiguration? = nil,
    alarmId: String? = nil, scheduleId: String? = nil,
    result: String = "ok", error: Error? = nil) {
    guard now.isFinite else { return }
    var values = entries.filter { $0.timeMillis >= now - retentionMillis }
    let expected = configuration?.fireAtMillis
    values.append(AlarmJournalEntry(
      timeMillis: now, operation: operation,
      alarmId: configuration?.alarmId ?? alarmId,
      scheduleId: configuration?.scheduleId ?? scheduleId,
      expectedMillis: expected?.isFinite == true ? expected : nil, result: result,
      errorCode: error.map(Self.errorCode)))
    if values.count > limit { values.removeFirst(values.count - limit) }
    do { defaults.set(try JSONEncoder().encode(values), forKey: Self.key) }
    catch { NSLog("alarm|journal|encode_failed") }
  }

  static func errorCode(_ error: Error) -> String {
    let value = error as NSError
    return "\(value.domain.prefix(100)):\(value.code)"
  }
}
