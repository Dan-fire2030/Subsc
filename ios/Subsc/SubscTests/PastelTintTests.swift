import SwiftUI
import UIKit
import XCTest
@testable import Subsc

/// 費目の色から作る**カードの面とアイコンの色**を縛るテストです。
///
/// 一覧の行は費目の色のパステルで塗ったカードになります（2026-10-15）。
/// 面が色を持つぶん、**その上の文字が読めるか**は色ごとに変わるため、7色すべて・両モードで測ります。
final class PastelTintTests: XCTestCase {
    private let minimumTextContrast = 4.5
    private let minimumGraphicContrast = 3.0

    /// 本文と補足の文字が、ライトのカードの上で読めること。
    func testTextReadsOnEveryLightCard() {
        for hex in SubscPalette.Category.hexes {
            let card = ColorHex.color(from: PastelTint.lightCardHex(for: hex))
            assertContrast(SubscPalette.text, on: card, style: .light, atLeast: minimumTextContrast, hex)
            assertContrast(SubscPalette.textMuted, on: card, style: .light, atLeast: minimumTextContrast, hex)
        }
    }

    /// 本文と補足の文字が、ダークのカードの上で読めること。
    func testTextReadsOnEveryDarkCard() {
        for hex in SubscPalette.Category.hexes {
            let card = ColorHex.color(from: PastelTint.darkCardHex(for: hex))
            assertContrast(SubscPalette.text, on: card, style: .dark, atLeast: minimumTextContrast, hex)
            assertContrast(SubscPalette.textMuted, on: card, style: .dark, atLeast: minimumTextContrast, hex)
        }
    }

    /// ライトのアイコンは白い丸の上に色付きで描くので、白に対して図形として見分けられること。
    func testLightIconInkStandsOutOnWhite() {
        for hex in SubscPalette.Category.hexes {
            let ink = ColorHex.color(from: PastelTint.iconInkHex(for: hex))
            assertContrast(ink, on: .white, style: .light, atLeast: minimumGraphicContrast, hex)
        }
    }

    /// カードの面は、もとの色と同じ色相に見えること（別の色に化けないこと）。
    func testCardsKeepTheHue() {
        for hex in SubscPalette.Category.hueTargets {
            let source = hue(of: hex)
            XCTAssertEqual(hue(of: PastelTint.lightCardHex(for: hex)), source, accuracy: 0.03, "\(hex) のライトのカード")
            XCTAssertEqual(hue(of: PastelTint.darkCardHex(for: hex)), source, accuracy: 0.05, "\(hex) のダークのカード")
        }
    }

    /// 保存値が壊れていても、カードの色は作れること。
    func testInvalidHexStillProducesColors() {
        XCTAssertEqual(PastelTint.lightCardHex(for: "ぬるぬる").count, 7)
        XCTAssertEqual(PastelTint.darkCardHex(for: "ぬるぬる").count, 7)
        XCTAssertEqual(PastelTint.iconInkHex(for: "ぬるぬる").count, 7)
    }

    // MARK: - 補助

    private func assertContrast(
        _ foreground: Color,
        on background: Color,
        style: UIUserInterfaceStyle,
        atLeast minimum: Double,
        _ hex: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let ratio = PaletteMeasure.ratio(foreground, background, style: style)
        XCTAssertGreaterThanOrEqual(ratio, minimum, "\(hex)：\(String(format: "%.2f", ratio)):1", file: file, line: line)
    }

    private func hue(of hex: String) -> CGFloat {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(ColorHex.color(from: hex)).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return hue
    }
}
