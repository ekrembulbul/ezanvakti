import AlarmKit
import Flutter
import Foundation

/// All bridge mutations and background intent actions share this queue.
@MainActor
final class AlarmKitHandler {
  static let shared = AlarmKitHandler()
  private let platform = AlarmKitPlatform()
  private lazy var engine = AlarmPlanEngine(platform: platform)
  private var channel: FlutterMethodChannel?
  private var operations: Task<Void, Never>?
  private var observations: Task<Void, Never>?
  private enum BridgeError: Error { case unsupported, badArguments }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.ekrembulbul.ezanvakti/alarm", binaryMessenger: registrar.messenger())
    shared.channel = channel
    shared.startObserving()
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

  private func startObserving() {
    guard #available(iOS 26.1, *), observations == nil else { return }
    observations = Task { @MainActor [weak self] in
      for await alarms in AlarmManager.shared.alarmUpdates {
        guard let self else { return }
        self.engine.observe(AlarmKitPlatform.states(alarms))
      }
    }
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
      case "reconcileAlarms":
        guard #available(iOS 26.1, *),
          let args = call.arguments as? [String: Any],
          (args["protocolVersion"] as? NSNumber)?.intValue == 2,
          let raw = args["records"] as? [[String: Any]],
          let enabled = args["enabledAlarmIds"] as? [String],
          let preserved = args["preserveAlarmIds"] as? [String],
          enabled.allSatisfy(Self.validId), preserved.allSatisfy(Self.validId)
        else { throw BridgeError.badArguments }
        let active = Set(enabled)
        guard Set(preserved).isSubset(of: active) else { throw BridgeError.badArguments }
        let periods = try (args["preservedPeriods"] as? [[String: Any]] ?? []).map { item -> AlarmPreservedPeriod in
          guard let root = item["alarmId"] as? String, active.contains(root),
            let from = (item["fromMillis"] as? NSNumber)?.doubleValue,
            let until = (item["untilMillis"] as? NSNumber)?.doubleValue,
            from.isFinite, until.isFinite, from > 0, until > from, until <= 8_640_000_000_000_000
          else { throw BridgeError.badArguments }
          return AlarmPreservedPeriod(alarmId: root, fromMillis: from, untilMillis: until)
        }
        let skips = try (args["skippedOccurrences"] as? [[String: Any]] ?? []).map { item -> AlarmSuppression in
          guard let id = item["alarmId"] as? String, active.contains(id),
            let fire = (item["fireAtMillis"] as? NSNumber)?.doubleValue,
            fire.isFinite, fire > 0, fire <= 8_640_000_000_000_000 else { throw BridgeError.badArguments }
          return AlarmSuppression(alarmId: id, fireAtMillis: fire)
        }
        let records = try raw.flatMap(Self.configurations)
        guard Set(records.map(\.scheduleId)).count == records.count,
          records.allSatisfy({ active.contains($0.alarmId) })
        else { throw BridgeError.badArguments }
        result(try await engine.reconcile(records: records,
          enabledAlarmIds: active, preserveAlarmIds: Set(preserved), skips: skips, preservedPeriods: periods))
      case "scheduleAlarm":
        guard #available(iOS 26.1, *) else { throw BridgeError.unsupported }
        guard let args = call.arguments as? [String: Any] else { throw BridgeError.badArguments }
        try await engine.scheduleLegacy(Self.configurations(args))
        result(nil)
      case "cancelAlarm":
        let request = try Self.request(call.arguments)
        try engine.cancelAlarm(request.id)
        result(nil)
      case "cancelAllAlarms":
        try engine.cancelAllLegacy()
        result(nil)
      case "getMissionSessions":
        result(try engine.snapshots())
      case "consumeMissionEvents":
        // Legacy bridge contract; current Flutter reads repeatable snapshots.
        try engine.missions.validateReadable()
        let id = (call.arguments as? [String: Any])?["alarmId"] as? String
        result(try engine.missions.consume(alarmId: id).map(\.dictionary))
      case "beginMission":
        let request = try Self.request(call.arguments)
        try await engine.begin(request.id, expectedFireMillis: request.fire)
        result(nil)
      case "snoozeMission":
        let request = try Self.request(call.arguments)
        guard let minutes = ((call.arguments as? [String: Any])?["minutes"] as? NSNumber)?.intValue,
          (1...1440).contains(minutes) else { throw BridgeError.badArguments }
        try await engine.snooze(request.id, minutes: minutes, expectedFireMillis: request.fire)
        result(nil)
      case "completeMission", "abortMission":
        let request = try Self.request(call.arguments)
        try engine.complete(request.id, expectedFireMillis: request.fire, aborted: call.method == "abortMission")
        result(nil)
      case "importCustomSound":
        let args = call.arguments as? [String: Any]
        result(platform.importCustomSound(path: args?["path"] as? String, name: args?["name"] as? String))
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      engine.journal.record(call.method, at: Date().timeIntervalSince1970 * 1000, result: "failed", error: error)
      result(FlutterError(code: "alarm_operation_failed", message: "Alarm operation failed",
        details: ["operation": call.method, "nativeCode": AlarmJournal.errorCode(error)]))
    }
  }

  func handleStop(scheduleId: String) async {
    await handleIntent(scheduleId: scheduleId, open: false)
  }

  func handleOpen(scheduleId: String) async {
    await handleIntent(scheduleId: scheduleId, open: true)
  }

  /// The stop was recorded; only the follow-up foregrounding was refused
  /// (typically a locked device). Kept in the journal so device audits can
  /// tell "stop lost" from "stop recorded, app stayed closed".
  func handleForegroundDeclined(scheduleId: String, error: Error) async {
    await enqueue {
      guard #available(iOS 26.1, *), Self.validId(scheduleId) else { return }
      self.engine.journal.record("stop_foreground",
        at: Date().timeIntervalSince1970 * 1000, scheduleId: scheduleId, result: "declined", error: error)
    }.value
  }

  private func handleIntent(scheduleId: String, open: Bool) async {
    await enqueue {
      guard #available(iOS 26.1, *), Self.validId(scheduleId) else { return }
      self.startObserving()
      do {
        let event = open
          ? try await self.engine.open(scheduleId: scheduleId)
          : try await self.engine.stop(scheduleId: scheduleId)
        if let event { self.channel?.invokeMethod("missionStopped", arguments: event.dictionary) }
      } catch {
        self.engine.journal.record(open ? "open" : "stop",
          at: Date().timeIntervalSince1970 * 1000, scheduleId: scheduleId, result: "failed", error: error)
      }
    }.value
  }

  private static func validId(_ id: String) -> Bool { !id.isEmpty && id.count <= 256 }

  private static func request(_ raw: Any?) throws -> (id: String, fire: Double?) {
    guard let args = raw as? [String: Any], let id = args["id"] as? String, validId(id)
    else { throw BridgeError.badArguments }
    var fire: Double?
    if let rawFire = args["firedAtMillis"] {
      guard let value = rawFire as? NSNumber, value.doubleValue.isFinite, value.doubleValue > 0, value.doubleValue <= 8_640_000_000_000_000
      else { throw BridgeError.badArguments }
      fire = value.doubleValue
    }
    return (id, fire)
  }

  private static func configurations(_ args: [String: Any]) throws -> [AlarmMissionConfiguration] {
    guard let id = args["id"] as? String, validId(id),
      let millis = (args["timeMillis"] as? NSNumber)?.doubleValue,
      millis.isFinite, millis > 0, millis <= 8_640_000_000_000_000 else { throw BridgeError.badArguments }
    let chain = args["chainConfig"] as? [String: Any] ?? [:]
    let theme = args["theme"] as? [String: Any] ?? [:]
    var record = AlarmMissionConfiguration(scheduleId: id,
      alarmId: chain["alarmId"] as? String ?? id, label: args["label"] as? String ?? "",
      fireAtMillis: millis, gated: (args["missionEnabled"] as? NSNumber)?.boolValue ?? false)
    record.snoozeEnabled = (args["snoozeEnabled"] as? NSNumber)?.boolValue ?? false
    record.snoozeMinutes = (args["snoozeMinutes"] as? NSNumber)?.intValue ?? 5
    record.maxSnoozes = (chain["maxSnoozes"] as? NSNumber)?.intValue
    record.repeatWeekdays = args["repeatWeekdays"] as? [Int] ?? []
    record.templateWeekdays = chain["templateWeekdays"] as? [Int]
    record.graceSeconds = (chain["graceSeconds"] as? NSNumber)?.intValue ?? 30
    record.maxRearms = (chain["maxRearms"] as? NSNumber)?.intValue ?? 40
    record.chainDurationMillis = (chain["chainDurationMillis"] as? NSNumber)?.doubleValue ?? 3_600_000
    record.missionTimeoutSeconds = (chain["missionTimeoutSeconds"] as? NSNumber)?.intValue ?? 90
    record.tintHex = theme["accent"] as? String ?? ""
    record.soundId = args["soundId"] as? String ?? "default"
    record.presentationVersion = 2
    guard validId(record.alarmId), (1...3600).contains(record.graceSeconds),
      (1...1000).contains(record.maxRearms),
      record.chainDurationMillis.isFinite, record.chainDurationMillis > 0,
      record.chainDurationMillis <= 7 * 86_400_000,
      (1...1440).contains(record.snoozeMinutes),
      record.maxSnoozes == nil || (0...1000).contains(record.maxSnoozes!),
      !record.gated || (1...3600).contains(record.missionTimeoutSeconds),
      record.repeatWeekdays.allSatisfy({ (1...7).contains($0) })
      && (record.templateWeekdays?.allSatisfy({ (1...7).contains($0) }) ?? true)
    else { throw BridgeError.badArguments }
    var records = [record]
    if record.gated, let ladder = chain["ladderMillis"] as? [NSNumber] {
      guard ladder.count <= 3 else { throw BridgeError.badArguments }
      for (index, time) in ladder.enumerated() {
        guard time.doubleValue.isFinite, time.doubleValue > millis,
          time.doubleValue < millis + record.chainDurationMillis
        else { throw BridgeError.badArguments }
        var child = record.chainConfiguration(
          scheduleId: "\(record.occurrenceId)#ladder\(index)",
          fireAtMillis: time.doubleValue, originalFireAtMillis: millis)
        child.isFallback = true
        records.append(child)
      }
    }
    return records
  }

  nonisolated static func localeWeekdays(fromIso days: [Int]) -> [Locale.Weekday] {
    AlarmKitPlatform.localeWeekdays(fromIso: days)
  }
}
