import Foundation
import XCTest
@testable import Subsc

final class ThemeColorTests: XCTestCase {
    private enum TestConstants {
        static let maximumCardLuminance = 0.179
        static let minimumCardLuminance = 0.02
        static let minimumButtonBrightness = 0.35
        static let hueTolerance = 2.0
        static let luminanceTolerance = 0.000_001
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

    func testReadableCardBaseKeepsEveryPresetWithinMaximumLuminance() throws {
        for preset in ThemeColorPreset.allCases {
            let result = ThemeColor.readableCardBase(from: preset.rawValue)
            XCTAssertLessThanOrEqual(
                try luminance(of: result),
                TestConstants.maximumCardLuminance + TestConstants.luminanceTolerance,
                "\(preset.title)の白文字コントラストが不足しています"
            )
        }
    }

    func testReadableCardBaseDoesNotChangeExistingCardBlue() {
        XCTAssertEqual(ThemeColor.readableCardBase(from: "#0D61EB"), "#0D61EB")
    }

    func testReadableCardBaseDarkensWhiteEnoughForWhiteText() throws {
        let result = ThemeColor.readableCardBase(from: "#FFFFFF")

        XCTAssertNotEqual(result, "#FFFFFF")
        XCTAssertLessThanOrEqual(
            try luminance(of: result),
            TestConstants.maximumCardLuminance + TestConstants.luminanceTolerance
        )
    }

    func testReadableCardBaseBrightensBlackToMinimumLuminance() throws {
        let result = ThemeColor.readableCardBase(from: "#000000")

        XCTAssertNotEqual(result, "#000000")
        XCTAssertGreaterThanOrEqual(
            try luminance(of: result),
            TestConstants.minimumCardLuminance - TestConstants.luminanceTolerance
        )
        XCTAssertLessThanOrEqual(
            try luminance(of: result),
            TestConstants.maximumCardLuminance + TestConstants.luminanceTolerance
        )
    }

    func testReadableCardBaseHandlesAchromaticGray() throws {
        let result = ThemeColor.readableCardBase(from: "#808080")
        let hsb = try hsb(of: result)

        XCTAssertEqual(hsb.saturation, 0, accuracy: 0.000_001)
        XCTAssertGreaterThanOrEqual(
            try luminance(of: result),
            TestConstants.minimumCardLuminance - TestConstants.luminanceTolerance
        )
        XCTAssertLessThanOrEqual(
            try luminance(of: result),
            TestConstants.maximumCardLuminance + TestConstants.luminanceTolerance
        )
    }

    func testReadableCardBasePreservesHueWhenCorrectingBrightness() throws {
        let originalHue = try hsb(of: "#34C759").hue
        let correctedHue = try hsb(of: ThemeColor.readableCardBase(from: "#34C759")).hue

        XCTAssertEqual(correctedHue, originalHue, accuracy: TestConstants.hueTolerance)
    }

    func testCardGradientAlwaysReturnsThreeStops() {
        XCTAssertEqual(ThemeColor.cardGradient(from: "#0D61EB").count, 3)
    }

    func testCardGradientMovesDefaultBlueTowardPurpleAndCyan() throws {
        let hues = try ThemeColor.cardGradient(from: "#0D61EB").map { try hsb(of: $0).hue }

        XCTAssertGreaterThan(hues[1], hues[0])
        XCTAssertLessThan(hues[2], hues[0])
    }

    func testCardGradientWrapsHueAroundZeroDegrees() throws {
        let hues = try ThemeColor.cardGradient(from: "#FF0000").map { try hsb(of: $0).hue }

        XCTAssertEqual(hues[0], 0, accuracy: TestConstants.hueTolerance)
        XCTAssertEqual(hues[1], 40, accuracy: TestConstants.hueTolerance)
        XCTAssertGreaterThan(hues[2], 330)
        XCTAssertLessThan(hues[2], 360)
    }

    /// 基準色だけ補正しても、色相と明度をずらした停止色で輝度が上がってしまいます。
    /// カードの右下に白文字が乗るため、**3色すべて**が読める必要があります。
    func testEveryGradientStopMeetsTheContrastRequirement() throws {
        let inputs = ThemeColorPreset.allCases.map(\.rawValue)
            + ["#0D61EB", "#FFFFFF", "#000000", "#808080", "#FF0000", "#00FF00"]

        for hex in inputs {
            for (index, stop) in ThemeColor.cardGradient(from: hex).enumerated() {
                XCTAssertLessThanOrEqual(
                    try luminance(of: stop),
                    TestConstants.maximumCardLuminance + TestConstants.luminanceTolerance,
                    "\(hex)の\(index + 1)色目(\(stop))で白文字のコントラストが不足しています"
                )
            }
        }
    }

    /// 補正で暗く潰れきってしまうと、グラデーションが単なる黒帯になります。
    func testEveryGradientStopStaysAboveTheMinimumLuminance() throws {
        for preset in ThemeColorPreset.allCases {
            for stop in ThemeColor.cardGradient(from: preset.rawValue) {
                XCTAssertGreaterThanOrEqual(
                    try luminance(of: stop),
                    TestConstants.minimumCardLuminance - TestConstants.luminanceTolerance,
                    "\(preset.title)の停止色\(stop)が暗くなりすぎています"
                )
            }
        }
    }

    /// 彩度の倍率が守られていないと、元のカードの立体感が再現できません。
    ///
    /// 明度は倍率をかけたあとに輝度の補正が入るため、**倍率どおりとは限りません**。
    /// 補正は暗くする方向にしか働かないので、上限として検証します。
    func testCardGradientAppliesSaturationMultipliersAndNeverBrightensBeyondThem() throws {
        let stops = try ThemeColor.cardGradient(from: "#0D61EB").map { try hsb(of: $0) }

        XCTAssertEqual(stops[1].saturation, stops[0].saturation * 0.80, accuracy: 0.02)
        XCTAssertEqual(stops[2].saturation, stops[0].saturation, accuracy: 0.02)
        XCTAssertLessThanOrEqual(stops[1].brightness, stops[0].brightness * 0.89 + 0.02)
        XCTAssertLessThanOrEqual(stops[2].brightness, stops[0].brightness * 0.957 + 0.02)
    }

    /// 明度だけを動かす設計なので、彩度が動くと「選んだ色」から離れてしまいます。
    func testReadableCardBasePreservesSaturationWhenCorrectingBrightness() throws {
        for hex in ["#FFFFFF", "#34C759", "#FF375F"] {
            let original = try hsb(of: hex)
            let corrected = try hsb(of: ThemeColor.readableCardBase(from: hex))

            XCTAssertEqual(
                corrected.saturation,
                original.saturation,
                accuracy: 0.02,
                "\(hex)の彩度が補正で変化しています"
            )
        }
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

    func testInvalidInputDoesNotCrashAndReturnsValidHexValues() {
        let cardBase = ThemeColor.readableCardBase(from: "#ZZZZZZ")
        let gradient = ThemeColor.cardGradient(from: "#ZZZZZZ")
        let buttonTint = ThemeColor.buttonTint(from: "#ZZZZZZ")

        XCTAssertTrue(isValidHex(cardBase))
        XCTAssertEqual(gradient.count, 3)
        XCTAssertTrue(gradient.allSatisfy(isValidHex))
        XCTAssertTrue(isValidHex(buttonTint))
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
