import SwiftUI
import UIKit
import XCTest
@testable import Subsc

/// 保存済みの費目色を、表示のときだけパステルの7色へ寄せる変換です。
final class HarmonizedColorTests: XCTestCase {
    /// 旧プリセット（iOS標準色）で保存された費目が、対応するパステルで表示されます。
    ///
    /// **色相の近さに任せず、対応表で決めています。** オレンジ（`#FF9F0A`）は色相だけなら
    /// バターに近く、利用者が「オレンジ」と選んだものが黄色で出てしまうためです。
    func testLegacyIOSPresetsMapToTheirPastelCounterparts() {
        let expected: [(legacy: String, harmonized: String)] = [
            ("#007AFF", "#9CC8FF"),  // ブルー → スカイ
            ("#34C759", "#8FDDB8"),  // グリーン → ミント
            ("#FF375F", "#F7A8C4"),  // ピンク → ローズ
            ("#AF52DE", "#B9A6FF"),  // パープル → ラベンダー
            ("#FF9F0A", "#FFB696")   // オレンジ → ピーチ
        ]
        assertMapping(expected)
    }

    /// 黒猫のパレット（2026-08-05〜2026-10-15）で保存された色も、意図した相手へ寄ります。
    func testLegacyBlackCatColorsMapToTheirPastelCounterparts() {
        let expected: [(legacy: String, harmonized: String)] = [
            ("#7FB3D5", "#9CC8FF"),  // 藍 → スカイ
            ("#9B8FD9", "#B9A6FF"),  // 菫 → ラベンダー
            ("#7FC8A9", "#8FDDB8"),  // 若草 → ミント
            ("#E0A66B", "#FFB696"),  // 琥珀 → ピーチ
            ("#D98FA6", "#F7A8C4"),  // 撫子 → ローズ
            ("#C4B37F", "#FFD966"),  // 黄土（通信費） → バター
            ("#8FA8C4", "#B9B4C9"),  // 鈍色（借入） → ミスト
            ("#D9A43C", "#FFD966")   // 金目 → バター
        ]
        assertMapping(expected)
    }

    /// **すでにパステルの色は、そのままの色で表示されます。**
    /// 変換で微妙にずれると、選んだ色と表示が食い違います。
    func testPastelColorsAreLeftUntouched() {
        for color in SubscPalette.Category.hexes {
            XCTAssertEqual(SubscPalette.harmonizedHex(from: color), color)
        }
    }

    /// 対応表は大文字小文字や `#` の有無に左右されません。
    func testLegacyLookupIgnoresNotation() {
        XCTAssertEqual(SubscPalette.harmonizedHex(from: "007aff"), "#9CC8FF")
    }

    /// 彩度の無い色（白・黒・灰）は色相で寄せられません。ミストへ倒します。
    func testAchromaticColorsFallBackToMist() {
        for hex in ["#FFFFFF", "#000000", "#8E8E93"] {
            XCTAssertEqual(SubscPalette.harmonizedHex(from: hex), "#B9B4C9")
        }
    }

    /// 解釈できない保存値でも落ちず、ミストで表示します。
    func testInvalidHexFallsBackToMist() {
        XCTAssertEqual(SubscPalette.harmonizedHex(from: "ぬるぬる"), "#B9B4C9")
    }

    /// 対応表に無い色は、色相が近いパステルへ寄ります（ブランド色など）。
    func testOtherHuesMapToTheNearestPastel() {
        XCTAssertEqual(SubscPalette.harmonizedHex(from: "#0000FF"), "#B9A6FF")
        XCTAssertEqual(SubscPalette.harmonizedHex(from: "#00FF00"), "#8FDDB8")
        XCTAssertEqual(SubscPalette.harmonizedHex(from: "#FFFF00"), "#FFD966")
    }

    /// **色のある費目はミストへ寄りません。** ミストは借入の色なので、紛れると見分けられません。
    func testChromaticColorsNeverMapToMist() {
        for hex in ["#5A7FA8", "#E50914", "#1DB954", "#A259FF", "#00A0E9"] {
            XCTAssertNotEqual(SubscPalette.harmonizedHex(from: hex), "#B9B4C9", "\(hex) がミストに寄りました")
        }
    }

    private func assertMapping(
        _ expected: [(legacy: String, harmonized: String)],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for (legacy, harmonized) in expected {
            XCTAssertEqual(
                SubscPalette.harmonizedHex(from: legacy),
                harmonized,
                "\(legacy) の寄せ先が想定と違います",
                file: file,
                line: line
            )
        }
    }
}

/// 内訳シートの色が、グラフ本体と同じ寄せ方を通っていることを縛ります。
///
/// **2026-08-11まで、内訳シートだけが保存値の色で描いていました。**
/// 同じ費目がグラフと内訳で違う色に見え、この画面だけ配色から浮いていました。
final class ReportBreakdownColorTests: XCTestCase {
    /// 旧プリセットで保存された費目は、内訳シートでもパステルになります。
    func testBreakdownUsesTheHarmonizedColor() {
        XCTAssertEqual(ReportChartPalette.breakdownBaseHex(for: "#007AFF"), "#9CC8FF")
        XCTAssertEqual(ReportChartPalette.breakdownBaseHex(for: "#34C759"), "#8FDDB8")
    }

    /// **保存値をそのまま使っていないこと**を明示的に縛ります。
    /// ここが素通りに戻ると、この画面だけまた浮きます。
    func testBreakdownDoesNotUseTheStoredColorDirectly() {
        XCTAssertNotEqual(ReportChartPalette.breakdownBaseHex(for: "#007AFF"), "#007AFF")
    }

    /// グラフ本体と出どころが同じであることを縛ります。
    func testBreakdownMatchesTheChartHarmonization() {
        for hex in ["#007AFF", "#FF375F", "#AF52DE", "#7FB3D5", "#123456"] {
            XCTAssertEqual(
                ReportChartPalette.breakdownBaseHex(for: hex),
                SubscPalette.harmonizedHex(from: hex),
                "\(hex) でグラフと内訳の寄せ先が食い違っています"
            )
        }
    }
}
