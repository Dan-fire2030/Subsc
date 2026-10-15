import SwiftUI
import UIKit
import XCTest
@testable import Subsc

/// パステルの配色で、**文字と操作の手がかりが読めること**を縛るテストです。
///
/// パステルは淡いため、面に使うぶんには優しく見えても、文字や印へ流用した瞬間に読めなくなります。
/// 目視では「少し薄いかな」としか分からず、比を測って初めて分かるため、ここで数値として固定します。
final class SubscPaletteContrastTests: XCTestCase {
    /// 本文の文字に求めるコントラストです（WCAG AA）。
    private let minimumTextContrast = 4.5
    /// 文字以外の図形（今日の印、選択の枠など）に求めるコントラストです。
    private let minimumGraphicContrast = 3.0
    private let styles: [UIUserInterfaceStyle] = [.light, .dark]

    func testTextReadsOnBackgroundAndSurfaceInBothModes() {
        for style in styles {
            for ground in [SubscPalette.background, SubscPalette.surface] {
                assertContrast(SubscPalette.text, on: ground, style: style, atLeast: minimumTextContrast)
                assertContrast(SubscPalette.textMuted, on: ground, style: style, atLeast: minimumTextContrast)
            }
        }
    }

    /// 補足の文字は、カードの中で沈む面（帯の下地など）の上にも置かれます。
    func testMutedTextReadsOnTheSunkenSurface() {
        for style in styles {
            assertContrast(
                SubscPalette.textMuted,
                on: SubscPalette.surfaceElevated,
                style: style,
                atLeast: minimumTextContrast
            )
        }
    }

    /// アクセントは「今日」や「選択中」の印に使います。文字ではないので図形の基準で測ります。
    func testAccentStandsOutAsAMarkInBothModes() {
        for style in styles {
            assertContrast(SubscPalette.accent, on: SubscPalette.surface, style: style, atLeast: minimumGraphicContrast)
        }
    }

    /// 増減の符号は金額そのものに当てる色なので、**文字の基準**で測ります。
    func testSignColorsReadAsTextInBothModes() {
        for style in styles {
            assertContrast(SubscPalette.positive, on: SubscPalette.surface, style: style, atLeast: minimumTextContrast)
            assertContrast(SubscPalette.caution, on: SubscPalette.surface, style: style, atLeast: minimumTextContrast)
        }
    }

    /// 曜日の見出し（日曜・土曜）は文字です。**費目のパステルを流用していないこと**を縛ります。
    /// 2026-10-15のリデザインで、パステルのままだと白地で 1.6:1 しか出ませんでした。
    func testWeekendLabelsReadInBothModes() {
        for style in styles {
            assertContrast(SubscPalette.sunday, on: SubscPalette.surface, style: style, atLeast: minimumTextContrast)
            assertContrast(SubscPalette.saturday, on: SubscPalette.surface, style: style, atLeast: minimumTextContrast)
        }
    }

    // MARK: - 補助

    private func assertContrast(
        _ foreground: Color,
        on background: Color,
        style: UIUserInterfaceStyle,
        atLeast minimum: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let ratio = PaletteMeasure.ratio(foreground, background, style: style)
        XCTAssertGreaterThanOrEqual(
            ratio,
            minimum,
            "\(style == .dark ? "ダーク" : "ライト")で \(String(format: "%.2f", ratio)):1 しかありません",
            file: file,
            line: line
        )
    }
}

/// 費目の色の一覧そのものを縛ります。
final class SubscPaletteCategoryTests: XCTestCase {
    /// パステルの7色です。**両モードで同じ色**を使います（色そのものが費目の識別子のため）。
    func testCategoryColorsAreTheSevenPastels() {
        XCTAssertEqual(
            SubscPalette.Category.hexes,
            ["#8FDDB8", "#FFB696", "#B9A6FF", "#9CC8FF", "#FFD966", "#F7A8C4", "#B9B4C9"]
        )
    }

    /// 寄せ先からミストを外します。ミストは借入と無彩色の逃げ場で、
    /// 色のある費目が借入と同じ色で並ぶと一覧で見分けられなくなるためです。
    func testMistIsNotAHueTarget() {
        XCTAssertFalse(SubscPalette.Category.hueTargets.contains("#B9B4C9"))
        XCTAssertEqual(SubscPalette.Category.hueTargets.count, 6)
    }

    /// 種別の色も同じパステルの体系から取ります。
    func testCostTypeColorsComeFromThePastels() {
        for type in CostType.allCases {
            XCTAssertTrue(
                SubscPalette.Category.hexes.contains(type.colorHex),
                "\(type.title) の色 \(type.colorHex) がパステルの7色にありません"
            )
        }
        XCTAssertEqual(CostType.loan.colorHex, SubscPalette.harmonizedFallbackHex)
    }
}

/// コントラスト比の計算です。テスト間で同じ式を使うために切り出しています。
enum PaletteMeasure {
    /// WCAG の相対輝度です。**モードを指定して解決します。**
    /// 動的な色をそのまま測ると、実行環境の外観に結果が左右されます。
    static func luminance(_ color: Color, style: UIUserInterfaceStyle) -> Double {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let channels = [red, green, blue].map { channel -> Double in
            let value = Double(channel)
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }

    static func ratio(_ lhs: Color, _ rhs: Color, style: UIUserInterfaceStyle) -> Double {
        let left = luminance(lhs, style: style)
        let right = luminance(rhs, style: style)
        return (max(left, right) + 0.05) / (min(left, right) + 0.05)
    }
}
