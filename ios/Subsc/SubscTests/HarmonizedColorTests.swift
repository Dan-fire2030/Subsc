import SwiftUI
import XCTest
@testable import Subsc

/// 保存済みの費目色を、表示のときだけ黒猫のパレットへ寄せる変換です。
final class HarmonizedColorTests: XCTestCase {
    /// 旧プリセット（iOS標準色）で保存された費目が、対応する黒猫の色で表示されます。
    func testLegacyPresetsMapToTheirBlackCatCounterparts() {
        let expected: [(legacy: String, harmonized: String)] = [
            ("#007AFF", "#7FB3D5"),  // ブルー → 藍
            ("#34C759", "#7FC8A9"),  // グリーン → 若草
            ("#FF375F", "#D98FA6"),  // ピンク → 撫子
            ("#AF52DE", "#9B8FD9"),  // パープル → 菫
            ("#FF9F0A", "#E0A66B")   // オレンジ → 琥珀
        ]

        for (legacy, harmonized) in expected {
            XCTAssertEqual(
                BlackCatPalette.harmonizedHex(from: legacy),
                harmonized,
                "\(legacy) の寄せ先が想定と違います"
            )
        }
    }

    /// **すでに黒猫のパレットの色は、そのままの色で表示されます。**
    /// 変換で微妙にずれると、選んだ色と表示が食い違います。
    func testBlackCatColorsAreLeftUntouched() {
        for color in ["#7FB3D5", "#9B8FD9", "#7FC8A9", "#E0A66B", "#D98FA6", "#C4B37F", "#8FA8C4"] {
            XCTAssertEqual(BlackCatPalette.harmonizedHex(from: color), color)
        }
    }

    /// **金目（アクセント）へは寄せません。** 金は予告や現在地といった一点のための色で、
    /// 費目に使うと「大事な一点」の意味が薄れます。
    func testNothingMapsToTheGoldAccent() {
        let goldish = ["#FFD60A", "#D9A43C", "#FFCC00", "#E8B44A"]
        for hex in goldish {
            XCTAssertNotEqual(BlackCatPalette.harmonizedHex(from: hex), "#D9A43C")
        }
    }

    /// 彩度の無い色（白・黒・灰）は色相で寄せられません。鈍色へ倒します。
    func testAchromaticColorsFallBackToSteel() {
        for hex in ["#FFFFFF", "#000000", "#8E8E93"] {
            XCTAssertEqual(BlackCatPalette.harmonizedHex(from: hex), "#8FA8C4")
        }
    }

    /// 解釈できない保存値でも落ちず、鈍色で表示します。
    func testInvalidHexFallsBackToSteel() {
        XCTAssertEqual(BlackCatPalette.harmonizedHex(from: "ぬるぬる"), "#8FA8C4")
    }

    /// 色相が近い順に寄るので、赤系は撫子、青系は藍になります。
    func testHuesMapToTheNearestCategoryColor() {
        XCTAssertEqual(BlackCatPalette.harmonizedHex(from: "#FF0000"), "#D98FA6")
        XCTAssertEqual(BlackCatPalette.harmonizedHex(from: "#0000FF"), "#9B8FD9")
    }
}
