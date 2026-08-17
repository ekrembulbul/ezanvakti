import ActivityKit
import AlarmKit
import AppIntents
import Flutter
import Foundation
import SwiftUI
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "EzanAlarmKit") {
      AlarmKitHandler.register(with: registrar)
    }
  }
}

/// Kullanıcı alarmı sistemin durdurma jestiyle susturduğunda çalışır.
///
/// Alarmın durmasını engellemez — durduğu bilgisini alır. İki iş yapar:
/// zinciri bir adım ileri kurar ve olayı kuyruğa yazar. Uygulamayı da açar,
/// böylece kullanıcı görev ekranına düşer.
@available(iOS 26.1, *)
struct MissionStopIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Alarmı durdur"
  static let openAppWhenRun: Bool = true

  init() {}

  func perform() async throws -> some IntentResult {
    MissionChainStore.handleStop()
    return .result()
  }
}

/// Zincirin native tarafındaki durumu.
///
/// Karar **değerleri** Dart'ta hesaplanır (bkz. `MissionChain`); burada
/// yalnızca iki karşılaştırma yapılır. Mantığın tek yerde kalması için.
@available(iOS 26.1, *)
enum MissionChainStore {
  static let sessionKey = "ezanvakti_mission_session"
  static let eventsKey = "ezanvakti_mission_events"

  static func session() -> [String: Any]? {
    UserDefaults.standard.dictionary(forKey: sessionKey)
  }

  static func save(_ session: [String: Any]) {
    UserDefaults.standard.set(session, forKey: sessionKey)
  }

  static func clear() {
    UserDefaults.standard.removeObject(forKey: sessionKey)
    UserDefaults.standard.removeObject(forKey: eventsKey)
  }

  /// Kullanıcı alarmı durdurdu: olayı kuyruğa yaz, sınır dolmadıysa nöbetçiyi
  /// kur. Yeni alarm kurmanın tek geçidi burasıdır.
  static func handleStop() {
    guard var s = session(), s["pending"] as? Bool == true,
      let alarmId = s["alarmId"] as? String
    else { return }

    enqueueStopEvent(alarmId: alarmId)

    let rearmCount = s["rearmCount"] as? Int ?? 0
    let maxRearms = s["maxRearms"] as? Int ?? 40
    let chainDeadline = s["chainDeadlineMillis"] as? Double ?? 0
    let nowMillis = Date().timeIntervalSince1970 * 1000

    // Cift ust sinir: bir hata sonsuz alarma donusmesin.
    guard rearmCount < maxRearms, nowMillis < chainDeadline else {
      s["pending"] = false
      save(s)
      NSLog("mission|chain|stopped|bounds|id=\(alarmId)")
      return
    }

    let grace = s["graceSeconds"] as? Int ?? 20
    let nextIndex = rearmCount + 1
    s["rearmCount"] = nextIndex
    s["deadlineMillis"] = nowMillis + Double(grace * 1000)
    save(s)

    AlarmKitHandler.scheduleWatchdog(
      alarmId: alarmId,
      index: nextIndex,
      fireDate: Date().addingTimeInterval(TimeInterval(grace)),
      session: s)
  }

  static func enqueueStopEvent(alarmId: String) {
    var queue =
      UserDefaults.standard.array(forKey: eventsKey) as? [[String: Any]] ?? []
    queue.append([
      "alarmId": alarmId,
      "stoppedAt": Date().timeIntervalSince1970 * 1000,
    ])
    UserDefaults.standard.set(queue, forKey: eventsKey)
  }

  static func drainEvents() -> [[String: Any]] {
    let queue =
      UserDefaults.standard.array(forKey: eventsKey) as? [[String: Any]] ?? []
    UserDefaults.standard.removeObject(forKey: eventsKey)
    return queue
  }
}

/// iOS 26+ AlarmKit ile sistem alarmı kurar/iptal eder. Dart `AlarmService` ile
/// `com.ekrembulbul.ezanvakti/alarm` kanalı üzerinden konuşur. iOS < 26'da
/// desteklenmez (no-op / false).
class AlarmKitHandler {
  private static let channelName = "com.ekrembulbul.ezanvakti/alarm"
  private static let mapKey = "ezanvakti_alarm_uuid_map"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName, binaryMessenger: registrar.messenger())
    let instance = AlarmKitHandler()
    channel.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      if #available(iOS 26.0, *) { result(true) } else { result(false) }
    case "isPermissionGranted":
      if #available(iOS 26.0, *) {
        result(AlarmManager.shared.authorizationState == .authorized)
      } else {
        result(false)
      }
    case "requestPermission":
      requestPermission(result)
    case "scheduleAlarm":
      scheduleAlarm(call.arguments, result)
    case "cancelAlarm":
      if let args = call.arguments as? [String: Any], let id = args["id"] as? String {
        cancel(idStr: id)
      }
      result(nil)
    case "cancelAllAlarms":
      cancelAll()
      result(nil)
    case "consumeMissionEvents":
      if #available(iOS 26.1, *) {
        result(MissionChainStore.drainEvents())
      } else {
        result([])
      }
    case "beginMission":
      beginMission(call.arguments, result)
    case "completeMission", "abortMission":
      endMission(result)
    case "importCustomSound":
      let args = call.arguments as? [String: Any]
      result(importCustomSound(path: args?["path"] as? String, name: args?["name"] as? String))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestPermission(_ result: @escaping FlutterResult) {
    guard #available(iOS 26.0, *) else {
      result(false)
      return
    }
    Task {
      do {
        let state = try await AlarmManager.shared.requestAuthorization()
        result(state == .authorized)
      } catch {
        result(false)
      }
    }
  }

  private func scheduleAlarm(_ arguments: Any?, _ result: @escaping FlutterResult) {
    // 26.1: stopButton'siz Alert init'i ve stopIntent bu surumde kullanilabilir.
    guard #available(iOS 26.1, *) else {
      result(nil)
      return
    }
    guard let args = arguments as? [String: Any],
      let idStr = args["id"] as? String,
      let timeMillis = (args["timeMillis"] as? NSNumber)?.int64Value
    else {
      result(FlutterError(code: "bad_args", message: "eksik arguman", details: nil))
      return
    }
    let label = args["label"] as? String ?? ""
    let date = Date(timeIntervalSince1970: Double(timeMillis) / 1000.0)
    let uuid = uuidFor(idStr)
    let sound = alertSound(args["soundId"] as? String)
    let snoozeEnabled = (args["snoozeEnabled"] as? NSNumber)?.boolValue ?? false
    let snoozeMinutes = (args["snoozeMinutes"] as? NSNumber)?.intValue ?? 5
    // Uyarının vurgu rengi: alarmın çalacağı anın paleti (Dart tarafı hesaplar).
    let theme = args["theme"] as? [String: Any]
    let tint = Self.color(fromHex: theme?["accent"] as? String) ?? Self.fallbackTint
    let missionEnabled = (args["missionEnabled"] as? NSNumber)?.boolValue ?? false
    let chainConfig = args["chainConfig"] as? [String: Any] ?? [:]

    let title: LocalizedStringResource =
      label.isEmpty ? "Ezan Vakti & Alarm" : LocalizedStringResource(stringLiteral: label)
    let alert: AlarmPresentation.Alert
    var countdownPresentation: AlarmPresentation.Countdown?
    var countdownDuration: Alarm.CountdownDuration?
    var stopIntent: (any LiveActivityIntent)?

    if missionEnabled {
      // Gorev acik: erteleme sistem uyarisindan kaldirilir (uygulama icine
      // tasindi), zincirin calisabilmesi icin stopIntent baglanir.
      alert = AlarmPresentation.Alert(title: title)
      stopIntent = MissionStopIntent()
    } else if snoozeEnabled {
      // Gorevsiz yol bugunku davranistir; dokunulmadi.
      let snoozeButton = AlarmButton(
        text: "Ertele", textColor: .white, systemImageName: "zzz")
      alert = AlarmPresentation.Alert(
        title: title,
        secondaryButton: snoozeButton, secondaryButtonBehavior: .countdown)
      countdownPresentation = AlarmPresentation.Countdown(title: "Erteleme")
      countdownDuration = Alarm.CountdownDuration(
        preAlert: nil, postAlert: Double(snoozeMinutes * 60))
    } else {
      alert = AlarmPresentation.Alert(title: title)
    }

    let presentation = AlarmPresentation(alert: alert, countdown: countdownPresentation)
    let attributes = AlarmAttributes<EzanAlarmMetadata>(
      presentation: presentation, metadata: EzanAlarmMetadata(), tintColor: tint)
    let config = AlarmManager.AlarmConfiguration(
      countdownDuration: countdownDuration,
      schedule: .fixed(date),
      attributes: attributes,
      stopIntent: stopIntent,
      sound: sound)

    Task {
      do {
        _ = try await AlarmManager.shared.schedule(id: uuid, configuration: config)
        if missionEnabled {
          var session: [String: Any] = chainConfig
          session["alarmId"] = idStr
          session["pending"] = true
          session["rearmCount"] = 0
          session["label"] = label
          session["tintHex"] = theme?["accent"] as? String ?? ""
          MissionChainStore.save(session)

          // Saglama merdiveni: stopIntent hic calismazsa kapi yine kapali
          // kalsin. Hizli zincirle id cakismasin diye 1000'den baslar.
          if let ladder = chainConfig["ladderMillis"] as? [Double] {
            for (i, millis) in ladder.enumerated() {
              Self.scheduleWatchdog(
                alarmId: idStr,
                index: 1000 + i,
                fireDate: Date(timeIntervalSince1970: millis / 1000),
                session: session)
            }
          }
        }
        result(nil)
      } catch {
        result(FlutterError(code: "schedule_failed", message: "\(error)", details: nil))
      }
    }
  }

  /// Nöbetçi alarm kurar. Id'si `<alarmId>#w<index>` — mevcut defter
  /// (`uuidFor`) üzerinden kaydedilir, böylece `cancelAll` hepsini yakalar.
  @available(iOS 26.1, *)
  static func scheduleWatchdog(
    alarmId: String, index: Int, fireDate: Date, session: [String: Any]
  ) {
    let handler = AlarmKitHandler()
    let watchdogId = "\(alarmId)#w\(index)"
    let uuid = handler.uuidFor(watchdogId)
    let label = session["label"] as? String ?? ""
    let title: LocalizedStringResource =
      label.isEmpty ? "Ezan Vakti & Alarm" : LocalizedStringResource(stringLiteral: label)
    let alert = AlarmPresentation.Alert(title: title)
    let attributes = AlarmAttributes<EzanAlarmMetadata>(
      presentation: AlarmPresentation(alert: alert),
      metadata: EzanAlarmMetadata(),
      tintColor: color(fromHex: session["tintHex"] as? String) ?? fallbackTint)
    let config = AlarmManager.AlarmConfiguration(
      schedule: .fixed(fireDate),
      attributes: attributes,
      stopIntent: MissionStopIntent(),
      sound: .default)
    Task {
      do {
        _ = try await AlarmManager.shared.schedule(id: uuid, configuration: config)
        NSLog("mission|watchdog|scheduled|id=\(watchdogId)")
      } catch {
        NSLog("mission|watchdog|failed|id=\(watchdogId)|\(error)")
      }
    }
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

  private func cancel(idStr: String) {
    guard #available(iOS 26.0, *) else { return }
    if let uuid = existingUuid(idStr) {
      try? AlarmManager.shared.cancel(id: uuid)
      removeMapping(idStr)
    }
  }

  /// Görev ekranı açıldı: son tarih `grace`ten görev süresine taşınır ve
  /// nöbetçi o tarihe yeniden kurulur.
  private func beginMission(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard #available(iOS 26.1, *),
      let args = arguments as? [String: Any],
      let idStr = args["id"] as? String,
      var session = MissionChainStore.session(),
      session["alarmId"] as? String == idStr
    else {
      result(nil)
      return
    }
    let timeout = session["missionTimeoutSeconds"] as? Int ?? 90
    let fireDate = Date().addingTimeInterval(TimeInterval(timeout))
    session["deadlineMillis"] = fireDate.timeIntervalSince1970 * 1000
    MissionChainStore.save(session)
    let index = session["rearmCount"] as? Int ?? 0
    Self.scheduleWatchdog(
      alarmId: idStr, index: index, fireDate: fireDate, session: session)
    result(nil)
  }

  /// Görev tamamlandı ya da acil çıkış kullanıldı: zincirdeki tüm alarmlar
  /// iptal edilir, oturum kapanır.
  private func endMission(_ result: @escaping FlutterResult) {
    guard #available(iOS 26.1, *) else {
      result(nil)
      return
    }
    cancelAll()
    MissionChainStore.clear()
    result(nil)
  }

  private func cancelAll() {
    guard #available(iOS 26.0, *) else { return }
    for (_, uuidStr) in uuidMap() {
      if let uuid = UUID(uuidString: uuidStr) {
        try? AlarmManager.shared.cancel(id: uuid)
      }
    }
    UserDefaults.standard.removeObject(forKey: Self.mapKey)
  }

  // MARK: - String id -> AlarmKit UUID eslemesi (UserDefaults'ta kalici)

  private func uuidMap() -> [String: String] {
    UserDefaults.standard.dictionary(forKey: Self.mapKey) as? [String: String] ?? [:]
  }

  private func existingUuid(_ idStr: String) -> UUID? {
    if let s = uuidMap()[idStr] { return UUID(uuidString: s) }
    return nil
  }

  private func uuidFor(_ idStr: String) -> UUID {
    if let u = existingUuid(idStr) { return u }
    let u = UUID()
    var m = uuidMap()
    m[idStr] = u.uuidString
    UserDefaults.standard.set(m, forKey: Self.mapKey)
    return u
  }

  private func removeMapping(_ idStr: String) {
    var m = uuidMap()
    m.removeValue(forKey: idStr)
    UserDefaults.standard.set(m, forKey: Self.mapKey)
  }
}

/// AlarmKit alarmları için (boş) metadata. AlarmMetadata = Codable + Hashable + Sendable.
@available(iOS 26.0, *)
struct EzanAlarmMetadata: AlarmMetadata {}
