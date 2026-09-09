import ActivityKit
import AlarmKit
import AppIntents
import Foundation
import SwiftUI

@MainActor
final class AlarmKitPlatform: AlarmPlatform {
  func alarms() throws -> [UUID: AlarmPlatformState] {
    guard #available(iOS 26.1, *) else { return [:] }
    return Self.states(try AlarmManager.shared.alarms)
  }

  @available(iOS 26.1, *)
  static func states(_ alarms: [Alarm]) -> [UUID: AlarmPlatformState] {
    Dictionary(uniqueKeysWithValues: alarms.map { alarm in
      let state: AlarmPlatformState
      switch alarm.state {
      case .scheduled: state = .scheduled
      case .alerting: state = .alerting
      case .countdown: state = .countdown
      case .paused: state = .paused
      @unknown default: state = .unknown
      }
      return (alarm.id, state)
    })
  }

  @available(iOS 26.1, *)
  static func presentation(for record: AlarmMissionConfiguration) -> AlarmPresentation {
    let title: LocalizedStringResource = record.label.isEmpty
      ? "Prayer Times & Alarm" : LocalizedStringResource(stringLiteral: record.label)
    // Only the system stop control. Stop records in the background and then
    // asks to come to the foreground itself (MissionStopIntent), so a separate
    // "open" button has no job left — gated or not, snooze or not.
    return AlarmPresentation(alert: AlarmPresentation.Alert(title: title))
  }

  func schedule(id: UUID, configuration record: AlarmMissionConfiguration) async throws {
    guard #available(iOS 26.1, *) else { throw AlarmPlanEngine.EngineError.unavailable }
    let date = Date(timeIntervalSince1970: record.fireAtMillis / 1000)
    let schedule: Alarm.Schedule
    if record.repeatWeekdays.isEmpty {
      schedule = .fixed(date)
    } else {
      let time = Calendar.current.dateComponents([.hour, .minute], from: date)
      schedule = .relative(.init(time: .init(hour: time.hour ?? 0, minute: time.minute ?? 0),
        repeats: .weekly(Self.localeWeekdays(fromIso: record.repeatWeekdays))))
    }
    let attributes = AlarmAttributes<EzanAlarmMetadata>(
      presentation: Self.presentation(for: record), metadata: EzanAlarmMetadata(),
      tintColor: Self.color(fromHex: record.tintHex) ?? Self.fallbackTint)
    let configuration = AlarmManager.AlarmConfiguration(schedule: schedule, attributes: attributes,
      stopIntent: MissionStopIntent(scheduleId: record.scheduleId),
      sound: alertSound(record.soundId))
    _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
  }

  func cancel(id: UUID) throws {
    guard #available(iOS 26.1, *) else { throw AlarmPlanEngine.EngineError.unavailable }
    try AlarmManager.shared.cancel(id: id)
  }

  func stop(id: UUID) throws {
    guard #available(iOS 26.1, *) else { throw AlarmPlanEngine.EngineError.unavailable }
    try AlarmManager.shared.stop(id: id)
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
  func importCustomSound(path: String?, name: String?) -> String? {
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
      NSLog("alarm|sound_import_failed")
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
