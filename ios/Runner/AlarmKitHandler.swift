import ActivityKit
import AlarmKit
import AppIntents
import Flutter
import Foundation
import SwiftUI

/// Serializes native mutations so a late schedule cannot outlive cancellation.
@MainActor
final class AlarmKitHandler {
  static let shared = AlarmKitHandler()
  private static let mapKey = "ezanvakti_alarm_uuid_map"
  private var channel: FlutterMethodChannel?
  private let missions = AlarmMissionStore()
  private var operations: Task<Void, Never>?

  private enum BridgeError: Error { case unsupported, badArguments, missionUnavailable }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.ekrembulbul.ezanvakti/alarm", binaryMessenger: registrar.messenger())
    shared.channel = channel
    channel.setMethodCallHandler { call, result in
      Self.shared.enqueue { await Self.shared.handle(call, result: result) }
    }
  }

  @discardableResult
  private func enqueue(_ operation: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
    let previous = operations
    let next = Task { @MainActor in
      await previous?.value
      await operation()
    }
    operations = next
    return next
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) async {
    do {
      switch call.method {
      case "isSupported":
        if #available(iOS 26.1, *) { result(true) } else { result(false) }
      case "isPermissionGranted":
        if #available(iOS 26.1, *) {
          result(AlarmManager.shared.authorizationState == .authorized)
        } else { result(false) }
      case "requestPermission":
        guard #available(iOS 26.1, *) else { result(false); return }
        result(try await AlarmManager.shared.requestAuthorization() == .authorized)
      case "scheduleAlarm":
        try await scheduleAlarm(call.arguments)
        result(nil)
      case "cancelAlarm":
        guard let id = (call.arguments as? [String: Any])?["id"] as? String else {
          throw BridgeError.badArguments
        }
        try cancelAlarm(id)
        result(nil)
      case "cancelAllAlarms":
        try cancelAll()
        result(nil)
      case "consumeMissionEvents":
        let id = (call.arguments as? [String: Any])?["alarmId"] as? String
        result(try missions.consume(alarmId: id).map(\.dictionary))
      case "beginMission", "snoozeMission":
        guard #available(iOS 26.1, *),
          let args = call.arguments as? [String: Any], let id = args["id"] as? String
        else { throw BridgeError.badArguments }
        let now = Date().timeIntervalSince1970 * 1000
        let previous = missions.session(alarmId: id)
        let session: AlarmMissionSession?
        if call.method == "beginMission" {
          let alreadyBegun = missions.session(alarmId: id)?.begun == true
          session = try missions.begin(alarmId: id, nowMillis: now)
          if alreadyBegun, session != nil { result(nil); return }
        } else {
          session = try missions.snooze(
            alarmId: id, minutes: (args["minutes"] as? NSNumber)?.intValue ?? 0, nowMillis: now)
        }
        guard let session, let next = session.snoozedUntilMillis ?? session.deadlineMillis else {
          throw BridgeError.missionUnavailable
        }
        do { try await rearmWatchdog(session: session, at: next) }
        catch {
          if let previous { try missions.restore(previous) }
          throw error
        }
        result(nil)
      case "completeMission", "abortMission":
        guard let id = (call.arguments as? [String: Any])?["id"] as? String else {
          throw BridgeError.badArguments
        }
        if let occurrence = missions.session(alarmId: id)?.occurrenceId {
          try cancelChain(occurrence)
        }
        try missions.finish(alarmId: id)
        result(nil)
      case "importCustomSound":
        let args = call.arguments as? [String: Any]
        result(importCustomSound(path: args?["path"] as? String, name: args?["name"] as? String))
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      NSLog("alarm|operation_failed|method=%@|error=%@", call.method, String(describing: error))
      result(FlutterError(code: "alarm_operation_failed", message: "Alarm operation failed", details: nil))
    }
  }

  func handleStop(scheduleId: String) async {
    await enqueue {
      guard #available(iOS 26.1, *), !scheduleId.isEmpty else {
        NSLog("alarm|stop_ignored|reason=missing_schedule_id")
        return
      }
      do {
        let now = Date().timeIntervalSince1970 * 1000
        guard let stopped = try self.missions.stop(scheduleId: scheduleId, nowMillis: now) else {
          NSLog("alarm|stop_ignored|id=%@|reason=unknown_or_completed", scheduleId)
          return
        }
        NSLog("alarm|stopped|id=%@|expected_ms=%.0f|stopped_ms=%.0f",
          stopped.event.alarmId, stopped.event.firedAt, stopped.event.stoppedAt)
        if let next = stopped.rearmAtMillis {
          do { try await self.rearmWatchdog(session: stopped.session, at: next) }
          catch { NSLog("alarm|watchdog_failed|id=%@|error=%@", scheduleId, String(describing: error)) }
        } else if stopped.event.chainStopped {
          try self.cancelChain(stopped.session.occurrenceId)
        }
        self.channel?.invokeMethod("missionStopped", arguments: stopped.event.dictionary)
      } catch {
        NSLog("alarm|stop_failed|id=%@|error=%@", scheduleId, String(describing: error))
      }
    }.value
  }

  private func scheduleAlarm(_ arguments: Any?) async throws {
    guard #available(iOS 26.1, *) else { throw BridgeError.unsupported }
    guard let args = arguments as? [String: Any],
      let id = args["id"] as? String, !id.isEmpty,
      let millis = (args["timeMillis"] as? NSNumber)?.doubleValue,
      millis.isFinite, millis > 0
    else { throw BridgeError.badArguments }
    // Refreshing while an alarm is alerting must not silence or relabel it.
    if let existing = existingUuid(id),
      try AlarmManager.shared.alarms.contains(where: { $0.id == existing && $0.state == .alerting })
    { return }
    let chain = args["chainConfig"] as? [String: Any] ?? [:]
    let theme = args["theme"] as? [String: Any] ?? [:]
    var record = AlarmMissionConfiguration(
      scheduleId: id, alarmId: chain["alarmId"] as? String ?? id,
      label: args["label"] as? String ?? "", fireAtMillis: millis,
      gated: (args["missionEnabled"] as? NSNumber)?.boolValue ?? false)
    record.snoozeEnabled = (args["snoozeEnabled"] as? NSNumber)?.boolValue ?? false
    record.snoozeMinutes = (args["snoozeMinutes"] as? NSNumber)?.intValue ?? 5
    record.maxSnoozes = (chain["maxSnoozes"] as? NSNumber)?.intValue
    record.repeatWeekdays = args["repeatWeekdays"] as? [Int] ?? []
    record.graceSeconds = (chain["graceSeconds"] as? NSNumber)?.intValue ?? 30
    record.maxRearms = (chain["maxRearms"] as? NSNumber)?.intValue ?? 40
    record.chainDurationMillis = (chain["chainDurationMillis"] as? NSNumber)?.doubleValue ?? 3_600_000
    record.missionTimeoutSeconds = (chain["missionTimeoutSeconds"] as? NSNumber)?.intValue ?? 90
    record.tintHex = theme["accent"] as? String ?? ""
    record.soundId = args["soundId"] as? String ?? "default"
    guard !record.alarmId.isEmpty, record.graceSeconds > 0, record.maxRearms > 0,
      record.chainDurationMillis.isFinite, record.chainDurationMillis > 0,
      record.snoozeMinutes > 0, !record.gated || record.missionTimeoutSeconds > 0,
      record.repeatWeekdays.allSatisfy({ (1...7).contains($0) })
    else { throw BridgeError.badArguments }
    try await schedule(record)
    // Existing +5/+10/+15 fallbacks stay attached to this occurrence only.
    if record.gated, let ladder = chain["ladderMillis"] as? [NSNumber] {
      for (index, time) in ladder.enumerated() where time.doubleValue.isFinite && time.doubleValue > millis {
        var child = record.chainConfiguration(
          scheduleId: "\(record.alarmId)#at\(Int64(millis))#ladder\(index)",
          fireAtMillis: time.doubleValue, originalFireAtMillis: millis)
        child.isFallback = true
        // An active/snoozed chain owns its timers; refresh must not add early fallbacks.
        if missions.activeOccurrences(nowMillis: Date().timeIntervalSince1970 * 1000)
          .contains("\(record.alarmId)#at\(Int64(millis))") { continue }
        do { try await schedule(child) }
        catch { NSLog("alarm|ladder_failed|id=%@|error=%@", child.scheduleId, String(describing: error)) }
      }
    }
  }

  @available(iOS 26.1, *)
  private func schedule(_ record: AlarmMissionConfiguration) async throws {
    let title: LocalizedStringResource = record.label.isEmpty
      ? "Prayer Times & Alarm" : LocalizedStringResource(stringLiteral: record.label)
    let attributes = AlarmAttributes<EzanAlarmMetadata>(
      presentation: AlarmPresentation(alert: AlarmPresentation.Alert(title: title)),
      metadata: EzanAlarmMetadata(), tintColor: Self.color(fromHex: record.tintHex) ?? Self.fallbackTint)
    let date = Date(timeIntervalSince1970: record.fireAtMillis / 1000)
    let schedule: Alarm.Schedule
    if record.repeatWeekdays.isEmpty {
      schedule = .fixed(date)
    } else {
      let time = Calendar.current.dateComponents([.hour, .minute], from: date)
      schedule = .relative(.init(
        time: .init(hour: time.hour ?? 0, minute: time.minute ?? 0),
        repeats: .weekly(Self.localeWeekdays(fromIso: record.repeatWeekdays))))
    }
    let opensApp = record.gated || record.snoozeEnabled
    let configuration = AlarmManager.AlarmConfiguration(
      schedule: schedule, attributes: attributes,
      stopIntent: opensApp ? MissionStopIntent(scheduleId: record.scheduleId) : nil,
      sound: alertSound(record.soundId))
    _ = try await AlarmManager.shared.schedule(id: uuidFor(record.scheduleId), configuration: configuration)
    try missions.configure(record)
    NSLog("alarm|scheduled|id=%@|expected_ms=%.0f|gated=%d",
      record.scheduleId, record.fireAtMillis, record.gated ? 1 : 0)
  }

  @available(iOS 26.1, *)
  private func rearmWatchdog(session: AlarmMissionSession, at millis: Double) async throws {
    let id = session.occurrenceId + "#w"
    // Snoozing must also cancel pre-planned +5/+10/+15 minute backups.
    try cancelChain(session.occurrenceId)
    let record = session.configuration.chainConfiguration(
      scheduleId: id, fireAtMillis: millis, originalFireAtMillis: session.firedAtMillis)
    try await schedule(record)
  }

  private func cancelChain(_ occurrenceId: String) throws {
    for key in MissionChainKeys.select(alarmId: occurrenceId, from: Array(uuidMap().keys)) {
      try cancelRecord(key)
    }
  }

  private func cancelAlarm(_ alarmId: String) throws {
    let records = missions.configurations
    for key in uuidMap().keys where key == alarmId ||
      records[key]?.alarmId == alarmId || key.hasPrefix(alarmId + "#") {
      try cancelRecord(key)
    }
    try missions.removeAlarm(alarmId)
  }

  private func cancelAll() throws {
    guard #available(iOS 26.1, *) else { return }
    let alarms = try AlarmManager.shared.alarms
    let alerting = Set(alarms.filter { $0.state == .alerting }.map(\.id))
    let protected = missions.activeOccurrences(nowMillis: Date().timeIntervalSince1970 * 1000)
    let mapping = uuidMap()
    for (key, uuidString) in mapping {
      if let uuid = UUID(uuidString: uuidString), alerting.contains(uuid) { continue }
      if protected.contains(where: { key.hasPrefix($0 + "#") }) { continue }
      try cancelRecord(key, retainingConfiguration: true)
    }
    // Old unawaited schedules could leave records outside the local id map.
    let known = Set(mapping.values.compactMap(UUID.init(uuidString:)))
    for alarm in alarms where !known.contains(alarm.id) && alarm.state != .alerting {
      try AlarmManager.shared.cancel(id: alarm.id)
    }
    try missions.retireConfigurations(
      keeping: Set(uuidMap().keys), nowMillis: Date().timeIntervalSince1970 * 1000)
    UserDefaults.standard.removeObject(forKey: "ezanvakti_mission_session")
    UserDefaults.standard.removeObject(forKey: "ezanvakti_mission_events")
  }

  private func cancelRecord(_ id: String, retainingConfiguration: Bool = false) throws {
    guard #available(iOS 26.1, *) else { return }
    if let uuid = existingUuid(id),
      try AlarmManager.shared.alarms.contains(where: { $0.id == uuid }) {
      try AlarmManager.shared.cancel(id: uuid)
    }
    var mapping = uuidMap()
    mapping.removeValue(forKey: id)
    UserDefaults.standard.set(mapping, forKey: Self.mapKey)
    if !retainingConfiguration { try missions.removeConfigurations([id]) }
  }

  private func uuidMap() -> [String: String] {
    UserDefaults.standard.dictionary(forKey: Self.mapKey) as? [String: String] ?? [:]
  }

  private func existingUuid(_ id: String) -> UUID? {
    uuidMap()[id].flatMap(UUID.init(uuidString:))
  }

  private func uuidFor(_ id: String) -> UUID {
    if let uuid = existingUuid(id) { return uuid }
    let uuid = UUID()
    var mapping = uuidMap()
    mapping[id] = uuid.uuidString
    UserDefaults.standard.set(mapping, forKey: Self.mapKey)
    return uuid
  }

  /// ISO hafta günlerini (1=Pazartesi..7=Pazar) `Locale.Weekday`e çevirir;
  /// tanınmayan değerler sessizce elenir (Dart tarafı 1..7 garanti eder).
  nonisolated static func localeWeekdays(fromIso days: [Int]) -> [Locale.Weekday] {
    let map: [Int: Locale.Weekday] = [
      1: .monday, 2: .tuesday, 3: .wednesday, 4: .thursday,
      5: .friday, 6: .saturday, 7: .sunday,
    ]
    return days.compactMap { map[$0] }
  }

  /// Vakit verisi yokken kullanılan palet (ERGUVAN) vurgusu; Dart tarafındaki
  /// `fallbackDayPhase` ile aynı renk.
  private static let fallbackTint = Color(
    .sRGB, red: 224.0 / 255.0, green: 159.0 / 255.0, blue: 184.0 / 255.0, opacity: 1)

  /// `#RRGGBB` biçimindeki rengi ayrıştırır; bozuk değer nil döner.
  private static func color(fromHex hex: String?) -> Color? {
    guard var text = hex, text.hasPrefix("#") else { return nil }
    text.removeFirst()
    guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
    return Color(
      .sRGB,
      red: Double((value >> 16) & 0xFF) / 255.0,
      green: Double((value >> 8) & 0xFF) / 255.0,
      blue: Double(value & 0xFF) / 255.0,
      opacity: 1)
  }

  /// soundId bundle'da bir ses dosyasına (ör. adhan.caf) ya da `custom:<ad>` ile
  /// Library/Sounds altındaki bir dosyaya karşılık geliyorsa onu, yoksa sistemin
  /// varsayılan alarm sesini döner.
  @available(iOS 26.0, *)
  private func alertSound(_ soundId: String?) -> ActivityKit.AlertConfiguration.AlertSound {
    guard let id = soundId, id != "default", !id.isEmpty else { return .default }
    if id.hasPrefix("custom:") {
      let name = String(id.dropFirst("custom:".count))
      if let dir = librarySoundsDir(),
        FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path)
      {
        return .named(name)
      }
      return .default
    }
    let hasFile = ["caf", "aiff", "wav", "mp3"].contains {
      Bundle.main.url(forResource: id, withExtension: $0) != nil
    }
    return hasFile ? .named(id) : .default
  }

  /// Kullanıcının seçtiği ses dosyasını Library/Sounds altına kopyalar; AlarmKit'in
  /// bulabilmesi için doğru konumdur. `custom:<ad>` döner. iOS yalnızca desteklenen
  /// biçimleri (caf/aiff/wav, ≤30 sn) çalar; diğerleri varsayılana düşer.
  private func importCustomSound(path: String?, name: String?) -> String? {
    guard let path = path, let name = name, !path.isEmpty, !name.isEmpty,
      let dir = librarySoundsDir()
    else { return nil }
    let safe = (name as NSString).lastPathComponent
    let fm = FileManager.default
    do {
      try fm.createDirectory(at: dir, withIntermediateDirectories: true)
      let dst = dir.appendingPathComponent(safe)
      if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
      try fm.copyItem(at: URL(fileURLWithPath: path), to: dst)
      return "custom:\(safe)"
    } catch {
      return nil
    }
  }

  private func librarySoundsDir() -> URL? {
    FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
      .appendingPathComponent("Sounds", isDirectory: true)
  }


}

@available(iOS 26.0, *)
struct EzanAlarmMetadata: AlarmMetadata {}
