import SwiftUI
import UIKit
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

/// 猫が地から分離して見えることを縛るテストです。
///
/// **1.04:1 という実質不可視の状態を、誰も気づかないまま出荷しかけました（2026-08-09）。**
/// ダークの体色は地より暗く置く設計で、白磁の地では影として正しく読めますが、
/// 墨の地では体と地が同じ色になっていました。**目視では「黒っぽい」としか分からず、
/// 比を測って初めて分かる**ため、ここで数値として固定します。
final class BlackCatContrastTests: XCTestCase {
    /// 文字以外の図形に求められる最低限のコントラストです。
    private let minimumGraphicContrast: Double = 3.0

    /// ライトでは体そのものが地に対して十分暗く、面を敷く必要がありません。
    func testCatBodyReadsAgainstTheLightBackground() {
        let contrast = ratio(
            BlackCatPalette.cat,
            BlackCatPalette.background,
            style: .light
        )

        XCTAssertGreaterThan(
            contrast,
            minimumGraphicContrast,
            "ライトで猫が地から分離していません：\(String(format: "%.2f", contrast)):1"
        )
    }

    /// **ダークは体ではなく、背後へ敷く面が分離を作ります。**
    /// 体は墨のまま（黒猫であること）を保つため、比は面と体のあいだで測ります。
    func testHaloSeparatesTheCatInDarkMode() {
        let contrast = ratio(
            BlackCatPalette.catHalo,
            BlackCatPalette.cat,
            style: .dark
        )

        XCTAssertGreaterThan(
            contrast,
            minimumGraphicContrast,
            "ダークで猫を浮かせられていません：\(String(format: "%.2f", contrast)):1"
        )
    }

    /// **体を明るくして解決していないこと。** 明るくすると黒猫でなくなるため、
    /// 体はカード面より暗いままであることを縛ります。
    func testCatBodyStaysDarkerThanTheSurfaceInDarkMode() {
        XCTAssertLessThan(
            luminance(BlackCatPalette.cat, style: .dark),
            luminance(BlackCatPalette.surface, style: .dark),
            "ダークの猫がカード面より明るくなっています。黒猫でなくなります。"
        )
    }

    /// 金の目は両モードで読めていること。猫の分離を直すときに巻き添えで潰さないためです。
    func testEyesReadInBothModes() {
        XCTAssertGreaterThan(
            ratio(BlackCatPalette.catEye, BlackCatPalette.cat, style: .light),
            minimumGraphicContrast
        )
        XCTAssertGreaterThan(
            ratio(BlackCatPalette.catEye, BlackCatPalette.cat, style: .dark),
            minimumGraphicContrast
        )
    }

    // MARK: - 補助

    /// WCAG の相対輝度です。**モードを指定して解決します。**
    /// 動的な色をそのまま測ると、実行環境の外観に結果が左右されます。
    private func luminance(_ color: Color, style: UIUserInterfaceStyle) -> Double {
        let resolved = UIColor(color).resolvedColor(
            with: UITraitCollection(userInterfaceStyle: style)
        )
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let channels = [red, green, blue].map { channel -> Double in
            let value = Double(channel)
            return value <= 0.03928
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }

    private func ratio(_ lhs: Color, _ rhs: Color, style: UIUserInterfaceStyle) -> Double {
        let left = luminance(lhs, style: style)
        let right = luminance(rhs, style: style)
        return (max(left, right) + 0.05) / (min(left, right) + 0.05)
    }
}

/// 内訳シートの色が、グラフ本体と同じ寄せ方を通っていることを縛ります。
///
/// **2026-08-11まで、内訳シートだけが保存値の色で描いていました。**
/// 同じ費目がグラフと内訳で違う色に見え、この画面だけ配色から浮いていました。
final class ReportBreakdownColorTests: XCTestCase {
    /// 旧プリセットで保存された費目は、内訳シートでも黒猫の色になります。
    func testBreakdownUsesTheHarmonizedColor() {
        XCTAssertEqual(ReportChartPalette.breakdownBaseHex(for: "#007AFF"), "#7FB3D5")
        XCTAssertEqual(ReportChartPalette.breakdownBaseHex(for: "#34C759"), "#7FC8A9")
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
                BlackCatPalette.harmonizedHex(from: hex),
                "\(hex) でグラフと内訳の寄せ先が食い違っています"
            )
        }
    }

    /// **グラデーションの段は3つのままです。** 色をそろえるついでに作りを変えていないこと。
    func testBreakdownKeepsItsThreeStops() {
        XCTAssertEqual(ReportChartPalette.breakdownSwatchColors(for: "#007AFF").count, 3)
    }
}
