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
  /// Aktif nöbetçinin id'si. Tek olması şart: `handleStop` ve `beginMission`
  /// aynı nöbetçiyi ileri atıyor, iki ayrı kayıt kalırsa erken çalar.
  static func activeWatchdogId(_ alarmId: String) -> String { "\(alarmId)#w" }

  static func handleStop() {
    guard var s = session(), s["pending"] as? Bool == true,
      let alarmId = s["alarmId"] as? String
    else { return }

    enqueueStopEvent(alarmId: alarmId)

    // Eski oturumlarda bayrak yok: hepsi gorevliydi.
    let gated = s["gated"] as? Bool ?? true
    let rearmCount = s["rearmCount"] as? Int ?? 0
    let maxRearms = s["maxRearms"] as? Int ?? 40
    let chainDeadline = s["chainDeadlineMillis"] as? Double ?? 0
    let nowMillis = Date().timeIntervalSince1970 * 1000

    switch MissionStopPolicy.action(
      gated: gated, rearmCount: rearmCount, maxRearms: maxRearms,
      nowMillis: nowMillis, chainDeadlineMillis: chainDeadline)
    {
    case .ignore:
      // Gorevsiz: durdurma kesin (spec 2026-08-30 D3). Uygulama acilinca
      // ara ekran erteleme sunar; olay kuyrukta.
      AlarmKitHandler.notifyDart(alarmId: alarmId)
      return
    case .stopChain:
      // Cift ust sinir: bir hata sonsuz alarma donusmesin.
      s["pending"] = false
      save(s)
      NSLog("mission|chain|stopped|bounds|id=\(alarmId)")
      return
    case .rearm:
      break
    }

    let grace = s["graceSeconds"] as? Int ?? 30
    s["rearmCount"] = rearmCount + 1
    s["deadlineMillis"] = nowMillis + Double(grace * 1000)
    save(s)

    AlarmKitHandler.rearmWatchdog(
      alarmId: alarmId,
      fireDate: Date().addingTimeInterval(TimeInterval(grace)),
      session: s)

    // Uygulama ayaktaysa dogrudan haber ver: yalnizca kuyruga yazmak yetmiyor,
    // on plandaki uygulamada hicbir yasam dongusu olayi tetiklenmiyor.
    AlarmKitHandler.notifyDart(alarmId: alarmId)
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

  /// Uygulama ayaktayken Dart'a haber verebilmek için saklanır. Kuyruk tek
  /// başına yetmiyor: ön plandaki uygulamada hiçbir yaşam döngüsü olayı
  /// tetiklenmediği için görev ekranı hiç açılmıyordu.
  private static var channel: FlutterMethodChannel?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName, binaryMessenger: registrar.messenger())
    Self.channel = channel
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
    case "snoozeMission":
      snoozeMission(call.arguments, result)
    case "completeMission", "abortMission":
      endMission(call.arguments, result)
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
    // Uyarının vurgu rengi: alarmın çalacağı anın paleti (Dart tarafı hesaplar).
    let theme = args["theme"] as? [String: Any]
    let tint = Self.color(fromHex: theme?["accent"] as? String) ?? Self.fallbackTint
    let missionEnabled = (args["missionEnabled"] as? NSNumber)?.boolValue ?? false
    let chainConfig = args["chainConfig"] as? [String: Any] ?? [:]

    let title: LocalizedStringResource =
      label.isEmpty ? "Ezan Vakti & Alarm" : LocalizedStringResource(stringLiteral: label)
    // Uyari yalnizca durdur dugmesi tasir. Sistemin Ertele dugmesi
    // (.countdown) sayilamiyordu; erteleme uygulama icindeki ara ekrana
    // tasindi (spec 2026-08-30 D5).
    let alert = AlarmPresentation.Alert(title: title)
    let countdownPresentation: AlarmPresentation.Countdown? = nil
    let countdownDuration: Alarm.CountdownDuration? = nil
    var stopIntent: (any LiveActivityIntent)?

    // Uygulamayi acan alarm: gorevli, ya da gorevsiz ama erteleme acik.
    // Erteleme kapali gorevsiz alarm bugunku gibi: sadece durdur, uygulama
    // acilmaz (D2).
    let opensApp = missionEnabled || snoozeEnabled
    if opensApp {
      stopIntent = MissionStopIntent()
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
        if opensApp {
          // Yapilandirma her planlamada tazelenir ama **canli durum**
          // korunur. scheduleAlarms uygulama one gelince, veri yenilenince,
          // alarm duzenlenince tekrar tekrar cagriliyor; burada pending ve
          // rearmCount sifirlansaydi guvenlik tavani hic birikmez ve durmus
          // bir zincir yeniden canlanirdi.
          let existing = MissionChainStore.session()
          let isSameAlarm = existing?["alarmId"] as? String == idStr
          var session: [String: Any] = chainConfig
          session["alarmId"] = idStr
          session["label"] = label
          // Gorevsizde durdurma kesin: handleStop nobetci kurmaz (D3/D10).
          session["gated"] = missionEnabled
          session["tintHex"] = theme?["accent"] as? String ?? ""
          if isSameAlarm, let existing {
            for key in [
              "pending", "rearmCount", "snoozeUsed", "deadlineMillis",
              "snoozedUntilMillis",
            ] {
              if let value = existing[key] { session[key] = value }
            }
          } else {
            session["pending"] = true
            session["rearmCount"] = 0
          }
          MissionChainStore.save(session)

          // Saglama merdiveni: stopIntent hic calismazsa kapi yine kapali
          // kalsin. Hizli zincirle id cakismasin diye 1000'den baslar.
          // Merdiven kapiyi kapali tutmak icin; gorevsizde kapi yok (D11).
          if missionEnabled, let ladder = chainConfig["ladderMillis"] as? [Double] {
            for (i, millis) in ladder.enumerated() {
              Self.scheduleLadderStep(
                alarmId: idStr,
                index: i,
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
  /// Uygulama ayaktaysa Dart'taki dinleyiciyi tetikler. Ayakta değilse
  /// çağrı sessizce düşer; olay zaten kuyrukta bekliyor.
  @available(iOS 26.1, *)
  static func notifyDart(alarmId: String) {
    DispatchQueue.main.async {
      channel?.invokeMethod(
        "missionStopped",
        arguments: [
          "alarmId": alarmId,
          "stoppedAt": Date().timeIntervalSince1970 * 1000,
        ])
    }
  }

  /// Sağlama merdiveni basamağı. Aktif nöbetçiden ayrı id'lerde durur;
  /// `stopIntent` hiç çalışmazsa kapıyı bunlar kapalı tutar.
  @available(iOS 26.1, *)
  static func scheduleLadderStep(
    alarmId: String, index: Int, fireDate: Date, session: [String: Any]
  ) {
    schedule(
      watchdogId: "\(alarmId)#ladder\(index)",
      fireDate: fireDate,
      session: session)
  }

  /// Aktif nöbetçiyi verilen tarihe **taşır**: önce mevcut kaydı iptal eder,
  /// sonra yenisini kurar. Aynı id ile üzerine yazmaya güvenmek erken çalmaya
  /// yol açıyordu.
  @available(iOS 26.1, *)
  static func rearmWatchdog(
    alarmId: String, fireDate: Date, session: [String: Any]
  ) {
    let watchdogId = MissionChainStore.activeWatchdogId(alarmId)
    AlarmKitHandler().cancel(idStr: watchdogId)
    schedule(watchdogId: watchdogId, fireDate: fireDate, session: session)
  }

  /// Nöbetçi alarmı kurar. Id defterden geçer (`uuidFor`), böylece
  /// `cancelAll` hepsini yakalar.
  @available(iOS 26.1, *)
  private static func schedule(
    watchdogId: String, fireDate: Date, session: [String: Any]
  ) {
    let uuid = AlarmKitHandler().uuidFor(watchdogId)
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

  fileprivate func cancel(idStr: String) {
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
    Self.rearmWatchdog(
      alarmId: idStr, fireDate: fireDate, session: session)
    result(nil)
  }

  /// Erteleme: aktif nöbetçi iptal edilip alarm verilen dakika kadar
  /// sonraya kurulur. Oturum açık kalır — görev hâlâ borç.
  private func snoozeMission(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard #available(iOS 26.1, *),
      let args = arguments as? [String: Any],
      let idStr = args["id"] as? String,
      var session = MissionChainStore.session(),
      session["alarmId"] as? String == idStr
    else {
      result(nil)
      return
    }
    let minutes = args["minutes"] as? Int ?? 5
    let fireDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
    // Son tarih silinir: gorev ekrani bir sonraki calista yeni sureyle acilir.
    session.removeValue(forKey: "deadlineMillis")
    MissionChainStore.save(session)
    Self.rearmWatchdog(alarmId: idStr, fireDate: fireDate, session: session)
    NSLog("mission|snooze|rearmed|id=\(idStr)|minutes=\(minutes)")
    result(nil)
  }

  /// Görev tamamlandı ya da acil çıkış kullanıldı: **yalnızca o alarmın**
  /// zinciri (nöbetçi + merdiven) iptal edilir, oturum kapanır.
  ///
  /// Eskiden `cancelAll` çağrılıyordu ve defterdeki her alarmı siliyordu:
  /// Güneş alarmının QR görevi tamamlanınca aynı güne kurulu 08:45 gitmişti.
  /// Birincil alarm da bilerek bırakılıyor — uygulama öne gelirken yeniden
  /// planlanmış olabilir ve aynı UUID'yi taşıyor; silmek yarınki çalışı
  /// da götürürdü.
  private func endMission(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard #available(iOS 26.1, *) else {
      result(nil)
      return
    }
    let alarmId =
      (arguments as? [String: Any])?["id"] as? String
      ?? MissionChainStore.session()?["alarmId"] as? String
    if let alarmId {
      for key in MissionChainKeys.select(alarmId: alarmId, from: Array(uuidMap().keys)) {
        cancel(idStr: key)
      }
    }
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

  fileprivate func existingUuid(_ idStr: String) -> UUID? {
    if let s = uuidMap()[idStr] { return UUID(uuidString: s) }
    return nil
  }

  fileprivate func uuidFor(_ idStr: String) -> UUID {
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
