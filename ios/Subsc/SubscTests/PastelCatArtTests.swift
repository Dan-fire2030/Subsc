import SwiftUI
import UIKit
import XCTest
@testable import Subsc

/// 新しい猫の**表情の対応表**を縛るテストです。
///
/// 猫は姿勢を変えず、目・耳・小さな符号だけで6つの気分を出し分けます（2026-10-15）。
/// 表情の差は小さいので、**並べて見分けがつくこと**をここで保証します。
final class CatExpressionTests: XCTestCase {
    /// 6つの気分が、すべて違う表情になっていること。
    /// 同じ表情が2つあると、猫を見ても状況が分かりません。
    func testEveryMoodHasItsOwnExpression() {
        let expressions = CatMood.allCases.map(CatExpression.init(mood:))
        XCTAssertEqual(Set(expressions).count, CatMood.allCases.count)
    }

    /// いつもどおりは、いちばん静かな顔（符号なし・耳は立てる・点の目）です。
    func testCalmIsTheQuietestFace() {
        let calm = CatExpression(mood: .calm)
        XCTAssertEqual(calm.eyes, .dot)
        XCTAssertEqual(calm.ears, .up)
        XCTAssertEqual(calm.accent, .none)
    }

    /// 支出が増えたときは、耳を伏せて汗をかきます。
    func testWorriedDroopsItsEarsAndSweats() {
        let worried = CatExpression(mood: .worried)
        XCTAssertEqual(worried.ears, .droop)
        XCTAssertEqual(worried.eyes, .worried)
        XCTAssertEqual(worried.accent, .sweat)
    }

    /// 支出が落ち着いているときは、目を細めて笑い、きらめきを添えます。
    func testPleasedSmilesWithASparkle() {
        let pleased = CatExpression(mood: .pleased)
        XCTAssertEqual(pleased.eyes, .smiling)
        XCTAssertEqual(pleased.accent, .sparkle)
    }

    /// 大きな支払いが近いときは、目を見開いて見張ります。
    func testWatchingOpensItsEyesWide() {
        XCTAssertEqual(CatExpression(mood: .watching).eyes, .wide)
    }

    /// 入力を促すときは「！」を出します。
    func testNudgingShowsAnExclamation() {
        XCTAssertEqual(CatExpression(mood: .nudging).accent, .exclamation)
    }

    /// 最初の案内では、横を見て点で方向を示します。
    func testGuidingLooksAside() {
        let guiding = CatExpression(mood: .guiding)
        XCTAssertEqual(guiding.eyes, .lookingAside)
        XCTAssertEqual(guiding.accent, .pointer)
    }
}

/// 新しい猫の**形**を縛るテストです。
final class PastelCatArtTests: XCTestCase {
    /// どの気分でも、図形が設計空間からはみ出さないこと。
    /// はみ出すと、表示枠の外が切れて耳や符号が欠けます。
    func testEveryShapeStaysInsideTheCanvas() {
        let canvas = CGRect(x: 0, y: 0, width: PastelCatArt.canvasSize, height: PastelCatArt.canvasSize)
        for mood in CatMood.allCases {
            for shape in PastelCatArt.shapes(for: CatExpression(mood: mood)) {
                let bounds = shape.path.boundingRect
                XCTAssertTrue(
                    canvas.contains(bounds),
                    "\(mood.rawValue) の \(shape.ink) が設計空間からはみ出しています：\(bounds)"
                )
            }
        }
    }

    /// 体と顔は、どの気分でも必ず描かれること。表情だけを差し替える作りなので、
    /// 体が抜けると猫そのものが消えます。
    func testBodyAndFaceAreAlwaysDrawn() {
        for mood in CatMood.allCases {
            let inks = Set(PastelCatArt.shapes(for: CatExpression(mood: mood)).map(\.ink))
            XCTAssertTrue(inks.isSuperset(of: [.body, .face, .nose]), "\(mood.rawValue) に体か顔が足りません")
        }
    }

    /// 符号を持たない表情では、符号の色の図形を描かないこと。
    func testNoAccentShapesWithoutAnAccent() {
        let calm = PastelCatArt.shapes(for: CatExpression(mood: .calm))
        XCTAssertFalse(calm.contains { $0.ink == .accent })
    }

    /// 符号を持つ表情では、符号の図形を描くこと。
    /// 汗だけは「ここを見て」の意味を持たない飾りなので、アクセントではなく汗の色で描きます。
    func testAccentShapesForEveryAccent() {
        for mood in CatMood.allCases where CatExpression(mood: mood).accent != .none {
            let shapes = PastelCatArt.shapes(for: CatExpression(mood: mood))
            XCTAssertTrue(
                shapes.contains { $0.ink == .accent || $0.ink == .sweat },
                "\(mood.rawValue) の符号が描かれていません"
            )
        }
    }

    /// 汗は飾りの色で描き、「！」や案内の点と同じ強さで目を引かないこと。
    func testSweatIsDrawnInItsOwnColor() {
        let shapes = PastelCatArt.shapes(for: CatExpression(mood: .worried))
        XCTAssertTrue(shapes.contains { $0.ink == .sweat })
        XCTAssertFalse(shapes.contains { $0.ink == .accent })
    }
}

/// 新しい猫が、カードの上で見えることを縛るテストです。
///
/// 前の黒猫では、ダークで体と地が 1.04:1 になり、**誰も気づかないまま消えかけました（2026-08-09）**。
/// パステルの猫でも同じことが起こり得るので、両モードで数値として固定します。
final class PastelCatContrastTests: XCTestCase {
    private let minimumGraphicContrast = 3.0
    private let styles: [UIUserInterfaceStyle] = [.light, .dark]

    /// 体はカードの面に対して、図形として見分けられる比を保つこと。
    func testBodyStandsOutOnTheCardInBothModes() {
        for style in styles {
            let ratio = PaletteMeasure.ratio(SubscPalette.catBody, SubscPalette.surface, style: style)
            XCTAssertGreaterThanOrEqual(ratio, minimumGraphicContrast, "\(style == .dark ? "ダーク" : "ライト")：\(ratio):1")
        }
    }

    /// 目や口元（顔の色）は体の上で読めること。表情が読めないと気分が伝わりません。
    func testFaceReadsOnTheBodyInBothModes() {
        for style in styles {
            let ratio = PaletteMeasure.ratio(SubscPalette.catFace, SubscPalette.catBody, style: style)
            XCTAssertGreaterThanOrEqual(ratio, minimumGraphicContrast, "\(style == .dark ? "ダーク" : "ライト")：\(ratio):1")
        }
    }

    /// 「！」や案内の点はカードの上に描くので、カードの面に対して見分けられること。
    func testAccentStandsOutOnTheCardInBothModes() {
        for style in styles {
            let ratio = PaletteMeasure.ratio(SubscPalette.catAccent, SubscPalette.surface, style: style)
            XCTAssertGreaterThanOrEqual(ratio, minimumGraphicContrast, "\(style == .dark ? "ダーク" : "ライト")：\(ratio):1")
        }
    }
}
