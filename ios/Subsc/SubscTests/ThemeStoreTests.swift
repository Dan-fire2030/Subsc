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

        XCTAssertEqual(store.buttonHex, "#1473FA")
        XCTAssertEqual(store.cardHex, "#0D61EB")
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

        XCTAssertEqual(ThemeStore(defaults: defaults).cardHex, "#0D61EB")
    }

    func testResetRestoresBothColors() {
        let store = ThemeStore(defaults: defaults)
        store.buttonHex = "#FF9F0A"
        store.cardHex = "#FF9F0A"

        store.resetToDefaults()

        XCTAssertTrue(store.isDefault)
        XCTAssertTrue(ThemeStore(defaults: defaults).isDefault)
    }

    /// 既定値はプリセットのブルー（`#007AFF`）とは別の色なので、
    /// 素直にプリセット名を引くと初期状態から「カスタム」に見えてしまいます。
    func testDefaultColorsAreNamedDefaultRatherThanCustom() {
        let store = ThemeStore(defaults: defaults)

        XCTAssertEqual(store.buttonColorName, "既定")
        XCTAssertEqual(store.cardColorName, "既定")
    }

    func testPresetAndCustomColorsKeepTheirOwnNames() {
        let store = ThemeStore(defaults: defaults)

        store.buttonHex = "#34C759"
        XCTAssertEqual(store.buttonColorName, "グリーン")

        store.cardHex = "#123456"
        XCTAssertEqual(store.cardColorName, "カスタム")
    }

    /// 大文字小文字や `#` の有無で「既定」判定が外れないことを確かめます。
    func testDefaultNameIgnoresHexFormatting() {
        let store = ThemeStore(defaults: defaults)
        store.buttonHex = "1473fa"

        XCTAssertEqual(store.buttonColorName, "既定")
        XCTAssertTrue(store.isDefault, "表示名と「既定に戻す」の判定基準が食い違っています")
    }

    /// 既定のカード色は補正の条件を満たすので、生成される1色目は指定どおりになります。
    func testDefaultCardGradientStartsFromTheStoredColor() {
        let store = ThemeStore(defaults: defaults)

        XCTAssertEqual(ThemeColor.cardGradient(from: store.cardHex).count, 3)
        XCTAssertEqual(ThemeColor.cardGradient(from: store.cardHex).first, "#0D61EB")
    }

    /// 読めない色を保存しても、画面が使う色は補正後になります。
    func testUnreadableCardColorIsCorrectedBeforeUse() {
        let store = ThemeStore(defaults: defaults)
        store.cardHex = "#FFFFFF"

        XCTAssertEqual(store.cardHex, "#FFFFFF", "保存値そのものは利用者の選択を残す")
        XCTAssertNotEqual(
            ThemeColor.readableCardBase(from: store.cardHex),
            "#FFFFFF",
            "画面が使う色は補正される"
        )
    }
}
