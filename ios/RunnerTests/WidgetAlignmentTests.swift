import SwiftUI
import XCTest

final class WidgetAlignmentTests: XCTestCase {
    func testDefaultIsLeading() {
        XCTAssertEqual(WidgetAlignment.default, .leading)
    }

    func testMapsToSwiftUIHorizontalAlignment() {
        XCTAssertEqual(WidgetAlignment.leading.horizontal, .leading)
        XCTAssertEqual(WidgetAlignment.center.horizontal, .center)
        XCTAssertEqual(WidgetAlignment.trailing.horizontal, .trailing)
    }

    func testMapsToTextAlignment() {
        XCTAssertEqual(WidgetAlignment.leading.textAlignment, .leading)
        XCTAssertEqual(WidgetAlignment.center.textAlignment, .center)
        XCTAssertEqual(WidgetAlignment.trailing.textAlignment, .trailing)
    }

    func testHasThreeCases() {
        XCTAssertEqual(WidgetAlignment.allCases.count, 3)
    }
}
