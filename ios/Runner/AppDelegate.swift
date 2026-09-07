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

/// Each stop intent carries the exact native schedule id.
@available(iOS 26.1, *)
struct MissionStopIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Stop alarm"
  static let openAppWhenRun: Bool = true

  @Parameter(title: "Alarm")
  var scheduleId: String

  init() { scheduleId = "" }
  init(scheduleId: String) { self.scheduleId = scheduleId }

  func perform() async throws -> some IntentResult {
    await AlarmKitHandler.shared.handleStop(scheduleId: scheduleId)
    return .result()
  }
}
