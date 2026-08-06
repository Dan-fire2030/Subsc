import Foundation
import XCTest
@testable import Subsc

final class ThemeColorTests: XCTestCase {
    private enum TestConstants {
        static let minimumButtonBrightness = 0.35
        static let hueTolerance = 2.0
    }

    func testPresetRawValuesAndTitlesMatchDefinitions() {
        // 黒猫のパレット（2026-08-05に入れ替え）。
        let expected: [(rawValue: String, title: String)] = [
            ("#D9A43C", "金目"),
            ("#7FB3D5", "藍"),
            ("#9B8FD9", "菫"),
            ("#7FC8A9", "若草"),
            ("#E0A66B", "琥珀"),
            ("#D98FA6", "撫子"),
            ("#8FA8C4", "鈍色")
        ]

        XCTAssertEqual(ThemeColorPreset.allCases.count, 7)
        XCTAssertEqual(ThemeColorPreset.allCases.map(\.rawValue), expected.map(\.rawValue))
        XCTAssertEqual(ThemeColorPreset.allCases.map(\.title), expected.map(\.title))
    }

    func testPresetTitleReturnsCustomForUnknownHex() {
        XCTAssertEqual(ThemeColorPreset.title(for: "#123456"), "カスタム")
        XCTAssertEqual(ThemeColorPreset.title(for: "#d9a43c"), "金目")
    }

    func testButtonTintRaisesBrightnessBelowMinimum() throws {
        let result = ThemeColor.buttonTint(from: "#110000")
        let resultHSB = try hsb(of: result)

        XCTAssertGreaterThanOrEqual(resultHSB.brightness, TestConstants.minimumButtonBrightness)
        XCTAssertEqual(resultHSB.hue, 0, accuracy: TestConstants.hueTolerance)
    }

    func testButtonTintDoesNotChangeColorAtOrAboveMinimum() {
        XCTAssertEqual(ThemeColor.buttonTint(from: "#5A0000"), "#5A0000")
    }

    /// 壊れた保存値でも落ちず、使える色を返します。
    /// **保存値は利用者が触れる文字列**なので、不正な入力は起こり得ます。
    func testInvalidInputDoesNotCrashAndReturnsAValidHexValue() {
        XCTAssertTrue(isValidHex(ThemeColor.buttonTint(from: "#ZZZZZZ")))
    }

}

private extension ThemeColorTests {
    struct RGB {
        let red: Double
        let green: Double
        let blue: Double
    }

    struct HSB {
        let hue: Double
        let saturation: Double
        let brightness: Double
    }

    func rgb(of hex: String) throws -> RGB {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
            throw TestError.invalidHex(hex)
        }
        return RGB(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    func hsb(of hex: String) throws -> HSB {
        let rgb = try rgb(of: hex)
        let maximum = max(rgb.red, rgb.green, rgb.blue)
        let minimum = min(rgb.red, rgb.green, rgb.blue)
        let delta = maximum - minimum
        let saturation = maximum == 0 ? 0 : delta / maximum
        let hue: Double

        if delta == 0 {
            hue = 0
        } else if maximum == rgb.red {
            hue = 60 * ((rgb.green - rgb.blue) / delta).truncatingRemainder(dividingBy: 6)
        } else if maximum == rgb.green {
            hue = 60 * (((rgb.blue - rgb.red) / delta) + 2)
        } else {
            hue = 60 * (((rgb.red - rgb.green) / delta) + 4)
        }

        return HSB(
            hue: hue < 0 ? hue + 360 : hue,
            saturation: saturation,
            brightness: maximum
        )
    }

    func luminance(of hex: String) throws -> Double {
        let rgb = try rgb(of: hex)
        return 0.2126 * linearized(rgb.red)
            + 0.7152 * linearized(rgb.green)
            + 0.0722 * linearized(rgb.blue)
    }

    func linearized(_ component: Double) -> Double {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }

    func isValidHex(_ value: String) -> Bool {
        guard value.count == 7, value.hasPrefix("#") else { return false }
        return value.dropFirst().allSatisfy(\.isHexDigit)
    }

    enum TestError: Error {
        case invalidHex(String)
    }
}
