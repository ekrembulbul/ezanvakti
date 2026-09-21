import UIKit
import XCTest

final class InkInsetsTests: XCTestCase {
    /// Paylar satır kutusunu tam büyük harf yüksekliğine indirir.
    func testInsetsTrimLineBoxToCapHeight() {
        for (size, weight) in [(CGFloat(16), UIFont.Weight.semibold), (26, .light), (11, .semibold)] {
            let font = UIFont.systemFont(ofSize: size, weight: weight)
            let insets = InkInsets.system(size: size, weight: weight)
            XCTAssertEqual(font.lineHeight - insets.top - insets.bottom, font.capHeight, accuracy: 0.01,
                           "size \(size)")
            XCTAssertGreaterThan(insets.top, 0)
            XCTAssertGreaterThan(insets.bottom, 0)
        }
    }

    /// SF Pro'da rakam üstü kutunun ~%25 altında, taban çizgisi ~%24 üstünde.
    func testSystemFontProportions() {
        let insets = InkInsets.system(size: 16, weight: .semibold)
        XCTAssertEqual(insets.top, 3.95, accuracy: 0.15)
        XCTAssertEqual(insets.bottom, 3.86, accuracy: 0.15)
        let countdown = InkInsets.system(size: 26, weight: .light)
        XCTAssertEqual(countdown.top, 6.42, accuracy: 0.2)
        XCTAssertEqual(countdown.bottom, 6.27, accuracy: 0.2)
    }
}
