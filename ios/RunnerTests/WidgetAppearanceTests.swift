import XCTest

final class WidgetAppearanceTests: XCTestCase {
    func testDecodesFullPayload() {
        let appearance = WidgetAppearance.decode(
            #"{"themeMode":"dark","timeBasedColor":false,"fixedPalette":"night"}"#
        )
        XCTAssertEqual(
            appearance,
            WidgetAppearance(themeMode: .dark, timeBasedColor: false, fixedPalette: .night)
        )
    }

    /// Bu anahtarı yazmayan eski sürümden gelen kullanıcı ya da hiç açılmamış
    /// uygulama: kurulum varsayılanı, yani cihaz görünümü + vakte göre renk.
    func testMissingPayloadFallsBackToInstallDefaults() {
        let appearance = WidgetAppearance.decode(nil)
        XCTAssertEqual(appearance, .fallback)
        XCTAssertEqual(appearance.themeMode, .system)
        XCTAssertTrue(appearance.timeBasedColor)
        XCTAssertEqual(appearance.fixedPalette, DayPhase.fallback)
    }

    func testMalformedPayloadFallsBack() {
        XCTAssertEqual(WidgetAppearance.decode("{ not json"), .fallback)
        XCTAssertEqual(WidgetAppearance.decode("[]"), .fallback)
    }

    /// Tek bir tanınmayan değer yalnızca kendi alanını düşürür; ileride
    /// eklenecek bir tema modu kullanıcının sabit paletini silmemeli.
    func testUnknownValuesFallBackPerField() {
        let appearance = WidgetAppearance.decode(
            #"{"themeMode":"amoled","timeBasedColor":false,"fixedPalette":"purple"}"#
        )
        XCTAssertEqual(appearance.themeMode, .system)
        XCTAssertFalse(appearance.timeBasedColor)
        XCTAssertEqual(appearance.fixedPalette, DayPhase.fallback)
    }

    func testMissingFieldsFallBackPerField() {
        let appearance = WidgetAppearance.decode(#"{"fixedPalette":"morning"}"#)
        XCTAssertEqual(appearance.themeMode, .system)
        XCTAssertTrue(appearance.timeBasedColor)
        XCTAssertEqual(appearance.fixedPalette, .morning)
    }

    func testDarkThemeIgnoresSystemScheme() {
        let appearance = WidgetAppearance(
            themeMode: .dark, timeBasedColor: true, fixedPalette: .evening
        )
        XCTAssertTrue(appearance.isDark(systemIsDark: false))
        XCTAssertTrue(appearance.isDark(systemIsDark: true))
    }

    func testLightThemeIgnoresSystemScheme() {
        let appearance = WidgetAppearance(
            themeMode: .light, timeBasedColor: true, fixedPalette: .evening
        )
        XCTAssertFalse(appearance.isDark(systemIsDark: true))
        XCTAssertFalse(appearance.isDark(systemIsDark: false))
    }

    func testSystemThemeFollowsSystemScheme() {
        let appearance = WidgetAppearance(
            themeMode: .system, timeBasedColor: true, fixedPalette: .evening
        )
        XCTAssertTrue(appearance.isDark(systemIsDark: true))
        XCTAssertFalse(appearance.isDark(systemIsDark: false))
    }

    func testFixedPaletteReplacesComputedPhase() {
        let appearance = WidgetAppearance(
            themeMode: .system, timeBasedColor: false, fixedPalette: .night
        )
        XCTAssertEqual(appearance.phase(timeBased: .morning), .night)
    }

    func testTimeBasedColorKeepsComputedPhase() {
        let appearance = WidgetAppearance(
            themeMode: .system, timeBasedColor: true, fixedPalette: .night
        )
        XCTAssertEqual(appearance.phase(timeBased: .morning), .morning)
    }
}
