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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "EzanHeading") {
      HeadingStreamHandler.register(with: registrar)
    }
  }
}

/// Recording a stop must not depend on unlocking or foregrounding Flutter.
@available(iOS 26.1, *)
struct MissionStopIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Stop alarm"
  static let openAppWhenRun: Bool = false
  static let isDiscoverable: Bool = false

  @Parameter(title: "Alarm")
  var scheduleId: String

  init() { scheduleId = "" }
  init(scheduleId: String) { self.scheduleId = scheduleId }

  func perform() async throws -> some IntentResult {
    await AlarmKitHandler.shared.handleStop(scheduleId: scheduleId)
    return .result()
  }
}

/// Foregrounding is a separate, explicitly labelled alarm action.
@available(iOS 26.1, *)
struct MissionOpenIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Open alarm"
  static let openAppWhenRun: Bool = true
  static let isDiscoverable: Bool = false

  @Parameter(title: "Alarm")
  var scheduleId: String

  init() { scheduleId = "" }
  init(scheduleId: String) { self.scheduleId = scheduleId }

  func perform() async throws -> some IntentResult {
    await AlarmKitHandler.shared.handleOpen(scheduleId: scheduleId)
    return .result()
  }
}
