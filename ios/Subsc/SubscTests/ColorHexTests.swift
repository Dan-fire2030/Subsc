import SwiftUI
import XCTest
@testable import Subsc

final class ColorHexTests: XCTestCase {
    /// **プリセットを直に並べ書きしません。** 配色を入れ替えたときに、
    /// テストだけが古い色を検査し続けるのを防ぎます。
    private let presets = ThemeColorPreset.allCases.map(\.rawValue)

    func testPresetColorsSurviveARoundTrip() {
        for hex in presets {
            let restored = ColorHex.string(from: ColorHex.color(from: hex))
            XCTAssertEqual(restored, hex, "\(hex)の往復変換が一致しません")
        }
    }

    func testHexWithoutHashIsAccepted() {
        XCTAssertEqual(ColorHex.canonical("007AFF"), "#007AFF")
    }

    func testLowercaseHexIsNormalizedToUppercase() {
        XCTAssertEqual(ColorHex.canonical("#007aff"), "#007AFF")
    }

    func testSurroundingWhitespaceIsIgnored() {
        XCTAssertEqual(ColorHex.canonical("  #007AFF \n"), "#007AFF")
    }

    func testInvalidCharactersFallBackToBlack() {
        XCTAssertEqual(ColorHex.canonical("#ZZZZZZ"), ColorHex.fallback)
        XCTAssertEqual(ColorHex.string(from: ColorHex.color(from: "#ZZZZZZ")), ColorHex.fallback)
    }

    func testWrongLengthFallsBackToBlack() {
        XCTAssertEqual(ColorHex.canonical("#FFF"), ColorHex.fallback)
        XCTAssertEqual(ColorHex.canonical("#0011223344"), ColorHex.fallback)
        XCTAssertEqual(ColorHex.canonical(""), ColorHex.fallback)
    }

    func testComponentsBelowRangeAreClampedToZero() {
        XCTAssertEqual(ColorHex.string(red: -0.4, green: 0, blue: 0), "#000000")
    }

    func testComponentsAboveRangeAreClampedToMaximum() {
        XCTAssertEqual(ColorHex.string(red: 1.3, green: 1, blue: 2.1), "#FFFFFF")
    }

    func testComponentsAreRoundedToTheNearestChannelValue() {
        // 0x80 = 128。128/255 = 0.50196... を往復させても値が落ちないこと。
        XCTAssertEqual(ColorHex.string(red: 128.0 / 255.0, green: 0, blue: 0), "#800000")
    }

    func testWhiteAndBlackConvertExactly() {
        XCTAssertEqual(ColorHex.string(from: ColorHex.color(from: "#FFFFFF")), "#FFFFFF")
        XCTAssertEqual(ColorHex.string(from: ColorHex.color(from: "#000000")), "#000000")
    }

    // MARK: - 上に置く文字の色

    func testDarkBackgroundsGetWhiteText() {
        XCTAssertFalse(ColorHex.prefersDarkText(on: "#000000"))
        XCTAssertFalse(ColorHex.prefersDarkText(on: "#E50914"))
        XCTAssertFalse(ColorHex.prefersDarkText(on: "#113CCF"))
    }

    func testWhiteBackgroundGetsDarkText() {
        XCTAssertTrue(ColorHex.prefersDarkText(on: "#FFFFFF"))
    }

    /// **黄色の上に白は読めません。** DAZN・povo・chocoZAP がこれに当たります。
    func testLightBackgroundsGetDarkText() {
        XCTAssertTrue(ColorHex.prefersDarkText(on: "#F8F800"))
        XCTAssertTrue(ColorHex.prefersDarkText(on: "#FFE100"))
        XCTAssertTrue(ColorHex.prefersDarkText(on: "#FFD400"))
        XCTAssertTrue(ColorHex.prefersDarkText(on: "#A2FA4B"))
    }

    /// 読み取れない値では、既定の白のままにします（従来の見え方を変えません）。
    func testUnreadableColorsKeepWhiteText() {
        XCTAssertFalse(ColorHex.prefersDarkText(on: "むり"))
    }
}
