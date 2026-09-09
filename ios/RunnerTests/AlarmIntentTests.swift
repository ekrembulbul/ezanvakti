import AlarmKit
import AppIntents
import XCTest
@testable import Runner

final class AlarmIntentTests: XCTestCase {
  @MainActor
  func testStopIntentCarriesExactScheduleIdentity() throws {
    guard #available(iOS 26.1, *) else { throw XCTSkip("AlarmKit requires iOS 26.1") }
    let id = "sample#at1800000000000#ladder0"
    XCTAssertEqual(MissionStopIntent(scheduleId: id).scheduleId, id)
  }

  /// Stop must record in the background first and only then ask to come to
  /// the foreground (`.foreground(.dynamic)`). `.foreground(.immediate)` is
  /// the iOS 26 name for `openAppWhenRun = true`: it makes the system require
  /// an unlocked device *before* perform() runs, which is exactly what lost
  /// the stop record on the locked phone on 8 September.
  @MainActor
  func testStopRecordsInBackgroundThenOffersToContinueInForeground() throws {
    guard #available(iOS 26.1, *) else { throw XCTSkip("AlarmKit requires iOS 26.1") }
    let modes = MissionStopIntent.supportedModes
    XCTAssertTrue(modes.contains(.background))
    XCTAssertTrue(modes.contains(.foreground(.dynamic)))
    XCTAssertFalse(modes.contains(.foreground(.immediate)))
  }

  /// The alert carries only the system stop control. Stop itself records in
  /// the background and then asks to come to the foreground; a separate
  /// "open" button no longer has a job, gated or not, snooze or not.
  @MainActor
  func testAlertHasNoSecondaryButtonForAnyAlarmKind() throws {
    guard #available(iOS 26.1, *) else { throw XCTSkip("AlarmKit requires iOS 26.1") }
    let gated = AlarmMissionConfiguration(scheduleId: "a", alarmId: "a",
      label: "Alarm", fireAtMillis: 1_800_000_000_000, gated: true, snoozeEnabled: false)
    var plain = AlarmMissionConfiguration(scheduleId: "b", alarmId: "b",
      label: "Alarm", fireAtMillis: 1_800_000_000_000, snoozeEnabled: false)
    XCTAssertNil(AlarmKitPlatform.presentation(for: gated).alert.secondaryButton)
    XCTAssertNil(AlarmKitPlatform.presentation(for: gated).alert.secondaryButtonBehavior)
    XCTAssertNil(AlarmKitPlatform.presentation(for: plain).alert.secondaryButton)
    plain.snoozeEnabled = true
    XCTAssertNil(AlarmKitPlatform.presentation(for: plain).alert.secondaryButton)
  }
}
