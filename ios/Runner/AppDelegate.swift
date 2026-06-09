import ActivityKit
import AlarmKit
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
    guard #available(iOS 26.0, *) else {
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

    let title: LocalizedStringResource =
      label.isEmpty ? "Ezan Vakti & Alarm" : LocalizedStringResource(stringLiteral: label)
    let stopButton = AlarmButton(
      text: "Kapat", textColor: .white, systemImageName: "stop.circle.fill")
    let alert = AlarmPresentation.Alert(title: title, stopButton: stopButton)
    let presentation = AlarmPresentation(alert: alert)
    let attributes = AlarmAttributes<EzanAlarmMetadata>(
      presentation: presentation, metadata: EzanAlarmMetadata(), tintColor: Color.yellow)
    let config = AlarmManager.AlarmConfiguration.alarm(
      schedule: .fixed(date), attributes: attributes, sound: sound)

    Task {
      do {
        _ = try await AlarmManager.shared.schedule(id: uuid, configuration: config)
        result(nil)
      } catch {
        result(FlutterError(code: "schedule_failed", message: "\(error)", details: nil))
      }
    }
  }

  /// soundId bundle'da bir ses dosyasına (ör. adhan.caf) karşılık geliyorsa onu,
  /// yoksa sistemin varsayılan alarm sesini döner. Gömülü ses dosyaları
  /// eklendiğinde ek koda gerek kalmadan çalışır.
  @available(iOS 26.0, *)
  private func alertSound(_ soundId: String?) -> ActivityKit.AlertConfiguration.AlertSound {
    guard let id = soundId, id != "default", !id.isEmpty else { return .default }
    let hasFile = ["caf", "aiff", "wav", "mp3"].contains {
      Bundle.main.url(forResource: id, withExtension: $0) != nil
    }
    return hasFile ? .named(id) : .default
  }

  private func cancel(idStr: String) {
    guard #available(iOS 26.0, *) else { return }
    if let uuid = existingUuid(idStr) {
      try? AlarmManager.shared.cancel(id: uuid)
      removeMapping(idStr)
    }
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
