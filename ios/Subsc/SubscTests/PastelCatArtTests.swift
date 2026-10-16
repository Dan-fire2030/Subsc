import SwiftUI
import UIKit
import XCTest
@testable import Subsc

/// 猫の**表情の対応表**を縛るテストです。
///
/// 猫は粘土の猫の絵（5枚）で、汗・きらめき・「！」・点はコードで重ねます（2026-10-16）。
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

/// 表情と**粘土の猫の絵**の対応を縛るテストです。
final class ClayCatImageTests: XCTestCase {
    /// どの気分の絵も、アプリに入っていること。名前を打ち間違えると、猫が黙って消えます。
    func testEveryMoodHasItsImageInTheApp() {
        for mood in CatMood.allCases {
            let name = CatExpression(mood: mood).imageName
            XCTAssertNotNil(UIImage(named: name), "\(mood.rawValue) の絵 \(name) がアプリにありません")
        }
    }

    /// 絵は5枚です。**催促はいつもどおりの絵に「！」を重ねます**（目は同じで、符号だけが違う）。
    func testNudgingSharesTheCalmImage() {
        XCTAssertEqual(CatExpression(mood: .nudging).imageName, CatExpression(mood: .calm).imageName)
        XCTAssertEqual(Set(CatMood.allCases.map { CatExpression(mood: $0).imageName }).count, 5)
    }

    /// 目が違う気分は、違う絵を使うこと。
    func testDifferentEyesUseDifferentImages() {
        let byEyes = Dictionary(grouping: CatMood.allCases.map(CatExpression.init(mood:)), by: \.eyes)
        let names = byEyes.values.compactMap { $0.first?.imageName }
        XCTAssertEqual(Set(names).count, byEyes.count)
    }
}

/// 猫に重ねる**符号**の形を縛るテストです。
final class CatAccentArtTests: XCTestCase {
    /// どの気分でも、符号が設計空間からはみ出さないこと。はみ出すと、表示枠の外が切れます。
    func testEveryAccentStaysInsideTheCanvas() {
        let canvas = CGRect(x: 0, y: 0, width: PastelCatArt.canvasSize, height: PastelCatArt.canvasSize)
        for mood in CatMood.allCases {
            for shape in PastelCatArt.accentShapes(for: CatExpression(mood: mood)) {
                XCTAssertTrue(
                    canvas.contains(shape.path.boundingRect),
                    "\(mood.rawValue) の符号が設計空間からはみ出しています：\(shape.path.boundingRect)"
                )
            }
        }
    }

    /// 符号を持たない表情では、何も重ねないこと。
    func testNoAccentShapesWithoutAnAccent() {
        XCTAssertTrue(PastelCatArt.accentShapes(for: CatExpression(mood: .calm)).isEmpty)
        XCTAssertTrue(PastelCatArt.accentShapes(for: CatExpression(mood: .watching)).isEmpty)
    }

    /// 符号を持つ表情では、符号の図形を描くこと。
    func testAccentShapesForEveryAccent() {
        for mood in CatMood.allCases where CatExpression(mood: mood).accent != .none {
            XCTAssertFalse(
                PastelCatArt.accentShapes(for: CatExpression(mood: mood)).isEmpty,
                "\(mood.rawValue) の符号が描かれていません"
            )
        }
    }

    /// 汗は飾りの色で描き、「！」や案内の点と同じ強さで目を引かないこと。
    func testSweatIsDrawnInItsOwnColor() {
        let shapes = PastelCatArt.accentShapes(for: CatExpression(mood: .worried))
        XCTAssertTrue(shapes.contains { $0.ink == .sweat })
        XCTAssertFalse(shapes.contains { $0.ink == .accent })
    }

    /// **符号は猫の耳に重ならない位置に置くこと。** 粘土の猫は耳が枠の上の角まで届くため、
    /// 「！」やきらめきは耳先より右上へ逃がしています。耳先の目安（右上の耳の内側）に掛からないことを縛ります。
    func testAccentsAvoidTheRightEarTip() {
        let rightEarTip = CGRect(x: 76, y: 14, width: 10, height: 12)
        for mood in [CatMood.nudging, .pleased] {
            for shape in PastelCatArt.accentShapes(for: CatExpression(mood: mood)) {
                XCTAssertFalse(
                    shape.path.boundingRect.intersects(rightEarTip),
                    "\(mood.rawValue) の符号が耳先に重なっています"
                )
            }
        }
    }
}

/// 猫に重ねる符号が、カードの上で見えることを縛るテストです。
final class PastelCatContrastTests: XCTestCase {
    private let minimumGraphicContrast = 3.0

    /// 「！」や案内の点はカードの上に描くので、カードの面に対して見分けられること。
    func testAccentStandsOutOnTheCardInBothModes() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let ratio = PaletteMeasure.ratio(SubscPalette.catAccent, SubscPalette.surface, style: style)
            XCTAssertGreaterThanOrEqual(ratio, minimumGraphicContrast, "\(style == .dark ? "ダーク" : "ライト")：\(ratio):1")
        }
    }
}
