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

    func testUsesCurrentAppearanceWhenNothingIsSaved() {
        let store = ThemeStore(defaults: defaults)

        XCTAssertEqual(store.buttonHex, "#D9A43C")
        XCTAssertEqual(store.cardHex, "#D9A43C")
        XCTAssertTrue(store.isDefault)
    }

    func testSavedValuesSurviveANewInstance() {
        let store = ThemeStore(defaults: defaults)
        store.buttonHex = "#34C759"
        store.cardHex = "#AF52DE"

        let restored = ThemeStore(defaults: defaults)

        XCTAssertEqual(restored.buttonHex, "#34C759")
        XCTAssertEqual(restored.cardHex, "#AF52DE")
        XCTAssertFalse(restored.isDefault)
    }

    func testButtonAndCardAreStoredIndependently() {
        let store = ThemeStore(defaults: defaults)
        store.buttonHex = "#FF375F"

        XCTAssertEqual(ThemeStore(defaults: defaults).cardHex, "#D9A43C")
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

    func testResetRestoresBothColors() {
        let store = ThemeStore(defaults: defaults)
        store.buttonHex = "#FF9F0A"
        store.cardHex = "#FF9F0A"

        store.resetToDefaults()

        XCTAssertTrue(store.isDefault)
        XCTAssertTrue(ThemeStore(defaults: defaults).isDefault)
    }

    /// 既定値はどのプリセットとも一致しない色なので、
    /// 素直にプリセット名を引くと初期状態から「カスタム」に見えてしまいます。
    func testDefaultColorsAreNamedDefaultRatherThanCustom() {
        let store = ThemeStore(defaults: defaults)

        XCTAssertEqual(store.buttonColorName, "既定")
        XCTAssertEqual(store.cardColorName, "既定")
    }

    func testPresetAndCustomColorsKeepTheirOwnNames() {
        let store = ThemeStore(defaults: defaults)

        store.buttonHex = "#7FC8A9"
        XCTAssertEqual(store.buttonColorName, "若草")

        store.cardHex = "#123456"
        XCTAssertEqual(store.cardColorName, "カスタム")
    }

    /// 大文字小文字や `#` の有無で「既定」判定が外れないことを確かめます。
    func testDefaultNameIgnoresHexFormatting() {
        let store = ThemeStore(defaults: defaults)
        store.buttonHex = "d9a43c"

        XCTAssertEqual(store.buttonColorName, "既定")
        XCTAssertTrue(store.isDefault, "表示名と「既定に戻す」の判定基準が食い違っています")
    }

    /// 既定のカード色（金目）は明るいため、**画面が使う色は暗く補正されます**。
    ///
    /// 補正は「この色を背景に白文字が読めるか」の基準で掛かります。
    /// 金目は白文字には明るすぎるので、そのままでは使われません。
    /// **保存値そのものは金目のまま**で、補正は表示のときだけ掛かります。
    ///
    /// **`ThemeColor` を直接呼ばず、画面が実際に使うプロパティ経由で確かめます。**
    /// 静的関数を呼んで検算すると、`cardBaseColor` から補正が消えてもテストが通ってしまいます。
    func testDefaultCardColorIsDarkenedBeforeUse() {
        let store = ThemeStore(defaults: defaults)

        XCTAssertEqual(store.cardHex, "#D9A43C", "保存値は既定のまま")
        XCTAssertEqual(store.cardGradientColors.count, 3)
        XCTAssertNotEqual(ColorHex.string(from: store.cardBaseColor), "#D9A43C")
        XCTAssertEqual(
            ColorHex.string(from: store.cardGradientColors[0]),
            ColorHex.string(from: store.cardBaseColor),
            "グラデーションの1色目は補正後の基準色と一致する"
        )
    }

    /// 読めない色を保存しても、画面が使う色は補正後になります。
    func testUnreadableCardColorIsCorrectedBeforeUse() {
        let store = ThemeStore(defaults: defaults)
        store.cardHex = "#FFFFFF"

        XCTAssertEqual(store.cardHex, "#FFFFFF", "保存値そのものは利用者の選択を残す")
        XCTAssertNotEqual(
            ColorHex.string(from: store.cardBaseColor),
            "#FFFFFF",
            "画面が使う色は補正される"
        )
        for color in store.cardGradientColors {
            XCTAssertNotEqual(ColorHex.string(from: color), "#FFFFFF")
        }
    }

    /// 保存値へ補正をかけていないことの確認です。かけていると選び直すたびに色がずれていきます。
    func testCorrectionIsNotAppliedRepeatedlyToTheStoredValue() {
        let store = ThemeStore(defaults: defaults)
        store.cardHex = "#FFFFFF"
        let first = ColorHex.string(from: store.cardBaseColor)

        // 同じ値をもう一度保存しても、画面が使う色は変わらないはず。
        store.cardHex = "#FFFFFF"

        XCTAssertEqual(ColorHex.string(from: store.cardBaseColor), first)
    }

    /// ボタン色も、画面が使うプロパティ経由で補正を確かめます。
    func testDarkButtonColorIsBrightenedBeforeUse() {
        let store = ThemeStore(defaults: defaults)
        store.buttonHex = "#110000"

        XCTAssertEqual(store.buttonHex, "#110000")
        XCTAssertNotEqual(ColorHex.string(from: store.buttonColor), "#110000")
    }
}
