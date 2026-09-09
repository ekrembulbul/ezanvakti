import AlarmKit
import AppIntents
import XCTest
@testable import Runner

final class AlarmIntentTests: XCTestCase {
  @MainActor
  func testStopAndOpenHaveSeparateForegroundRequirementsAndExactIdentity() throws {
    guard #available(iOS 26.1, *) else { throw XCTSkip("AlarmKit requires iOS 26.1") }
    let id = "sample#at1800000000000#ladder0"
    XCTAssertTrue(MissionOpenIntent.openAppWhenRun)
    XCTAssertEqual(MissionStopIntent(scheduleId: id).scheduleId, id)
    XCTAssertEqual(MissionOpenIntent(scheduleId: id).scheduleId, id)
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

  @MainActor
  func testGatedAlarmExposesTaskActionEvenWhenSnoozeIsDisabled() throws {
    guard #available(iOS 26.1, *) else { throw XCTSkip("AlarmKit requires iOS 26.1") }
    let record = AlarmMissionConfiguration(scheduleId: "a", alarmId: "a",
      label: "Alarm", fireAtMillis: 1_800_000_000_000, gated: true, snoozeEnabled: false)
    let alert = AlarmKitPlatform.presentation(for: record).alert
    XCTAssertEqual(alert.secondaryButtonBehavior, .custom)
    XCTAssertEqual(String(localized: try XCTUnwrap(alert.secondaryButton).text), String(localized: "Open task"))
  }

  @MainActor
  func testPlainAlarmHasNoAppActionUnlessSnoozeIsEnabled() throws {
    guard #available(iOS 26.1, *) else { throw XCTSkip("AlarmKit requires iOS 26.1") }
    var record = AlarmMissionConfiguration(scheduleId: "a", alarmId: "a",
      label: "Alarm", fireAtMillis: 1_800_000_000_000, snoozeEnabled: false)
    XCTAssertNil(AlarmKitPlatform.presentation(for: record).alert.secondaryButton)
    record.snoozeEnabled = true
    let alert = AlarmKitPlatform.presentation(for: record).alert
    XCTAssertEqual(String(localized: try XCTUnwrap(alert.secondaryButton).text), String(localized: "Open alarm"))
  }
}
