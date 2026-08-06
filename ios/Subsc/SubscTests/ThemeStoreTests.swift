import XCTest
@testable import Subsc

final class ThemeStoreTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        // 実行者本人の設定を汚さないよう、テストごとに独立したsuiteを使います。
        suiteName = "ThemeStoreTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testUsesTheDefaultButtonColorWhenNothingIsSaved() {
        let store = ThemeStore(defaults: defaults)

        XCTAssertEqual(store.buttonHex, "#D9A43C")
        XCTAssertTrue(store.isDefault)
    }

    func testSavedButtonColorSurvivesANewInstance() {
        let store = ThemeStore(defaults: defaults)
        store.buttonHex = "#34C759"

        let restored = ThemeStore(defaults: defaults)

        XCTAssertEqual(restored.buttonHex, "#34C759")
        XCTAssertFalse(restored.isDefault)
    }

    func testResetRestoresTheButtonColor() {
        let store = ThemeStore(defaults: defaults)
        store.buttonHex = "#FF9F0A"

        store.resetToDefaults()

        XCTAssertTrue(store.isDefault)
        XCTAssertTrue(ThemeStore(defaults: defaults).isDefault)
    }

    /// 既定値はどのプリセットとも一致しない色なので、
    /// 素直にプリセット名を引くと初期状態から「カスタム」に見えてしまいます。
    func testDefaultButtonColorIsNamedDefaultRatherThanCustom() {
        XCTAssertEqual(ThemeStore(defaults: defaults).buttonColorName, "既定")
    }

    func testPresetAndCustomButtonColorsKeepTheirOwnNames() {
        let store = ThemeStore(defaults: defaults)

        store.buttonHex = "#7FC8A9"
        XCTAssertEqual(store.buttonColorName, "若草")

        store.buttonHex = "#123456"
        XCTAssertEqual(store.buttonColorName, "カスタム")
    }

    func testChartStyleDefaultsToBar() {
        XCTAssertEqual(ThemeStore(defaults: defaults).chartStyle, .bar)
    }

    func testChartStyleSurvivesANewInstance() {
        let store = ThemeStore(defaults: defaults)
        store.chartStyle = .bubble

        XCTAssertEqual(ThemeStore(defaults: defaults).chartStyle, .bubble)
        XCTAssertFalse(ThemeStore(defaults: defaults).isDefault)
    }

    /// 保存値が壊れていても起動を止めず、既定へ倒します。
    func testUnknownSavedChartStyleFallsBackToTheDefault() {
        defaults.set("存在しない表示", forKey: "theme.chartStyle")

        XCTAssertEqual(ThemeStore(defaults: defaults).chartStyle, .bar)
    }

    func testResetRestoresChartStyleToo() {
        let store = ThemeStore(defaults: defaults)
        store.chartStyle = .column

        store.resetToDefaults()

        XCTAssertEqual(store.chartStyle, .bar)
        XCTAssertTrue(store.isDefault)
    }

    /// 大文字小文字や `#` の有無で「既定」判定が外れないことを確かめます。
    func testDefaultNameIgnoresHexFormatting() {
        let store = ThemeStore(defaults: defaults)
        store.buttonHex = "d9a43c"

        XCTAssertEqual(store.buttonColorName, "既定")
        XCTAssertTrue(store.isDefault, "表示名と「既定に戻す」の判定基準が食い違っています")
    }

    /// ボタン色も、画面が使うプロパティ経由で補正を確かめます。
    func testDarkButtonColorIsBrightenedBeforeUse() {
        let store = ThemeStore(defaults: defaults)
        store.buttonHex = "#110000"

        XCTAssertEqual(store.buttonHex, "#110000")
        XCTAssertNotEqual(ColorHex.string(from: store.buttonColor), "#110000")
    }
}
