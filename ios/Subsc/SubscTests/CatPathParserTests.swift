import XCTest
import SwiftUI
@testable import Subsc

/// 猫の絵はSVGのパスデータから組み立てるため、**その変換が正しいことを先に固定します。**
///
/// 絵そのものは目で見るしかありませんが、**パスデータの読み違えは数値で検出できます**。
/// 座標が1つずれただけで顔が崩れ、しかも画面を見るまで気づけないため、ここで止めます。
final class CatPathParserTests: XCTestCase {
    // MARK: - 命令ごとの変換

    func testMoveAndCloseOnly() {
        let path = CatPathParser.path(from: "M10 20 Z")
        XCTAssertEqual(elements(of: path), ["M(10.0,20.0)", "Z"])
    }

    func testCubicCurveTakesThreePointsInOrder() {
        let path = CatPathParser.path(from: "M0 0 C1 2, 3 4, 5 6 Z")
        XCTAssertEqual(
            elements(of: path),
            ["M(0.0,0.0)", "C(5.0,6.0)|(1.0,2.0)|(3.0,4.0)", "Z"]
        )
    }

    /// 命令を繰り返し書かず、数値だけを続けて並べる書き方に対応します。
    func testRepeatedCurveOmitsCommandLetter() {
        let path = CatPathParser.path(from: "M0 0 C1 1, 2 2, 3 3 4 4, 5 5, 6 6 Z")
        XCTAssertEqual(
            elements(of: path),
            [
                "M(0.0,0.0)",
                "C(3.0,3.0)|(1.0,1.0)|(2.0,2.0)",
                "C(6.0,6.0)|(4.0,4.0)|(5.0,5.0)",
                "Z"
            ]
        )
    }

    func testMultipleSubpaths() {
        let path = CatPathParser.path(from: "M0 0 Z M10 10 Z")
        XCTAssertEqual(elements(of: path), ["M(0.0,0.0)", "Z", "M(10.0,10.0)", "Z"])
    }

    // MARK: - 数値の読み取り

    func testNegativeAndDecimalCoordinates() {
        let path = CatPathParser.path(from: "M-4.5 -0.25 Z")
        XCTAssertEqual(elements(of: path), ["M(-4.5,-0.25)", "Z"])
    }

    /// 区切りはカンマでも空白でも改行でもよく、混在も許します。
    /// 生成元によって書式が揺れるため、ここで吸収します。
    func testSeparatorsAreInterchangeable() {
        let spaced = CatPathParser.path(from: "M 0 0 C 1 2 3 4 5 6 Z")
        let commas = CatPathParser.path(from: "M0,0C1,2,3,4,5,6Z")
        let newlines = CatPathParser.path(from: "M0 0\n  C1 2,\n  3 4,\n  5 6\nZ")
        XCTAssertEqual(elements(of: spaced), elements(of: commas))
        XCTAssertEqual(elements(of: spaced), elements(of: newlines))
    }

    // MARK: - 壊れた入力

    func testEmptyStringProducesEmptyPath() {
        XCTAssertTrue(CatPathParser.path(from: "").isEmpty)
        XCTAssertTrue(CatPathParser.path(from: "   \n ").isEmpty)
    }

    /// **数が足りない命令は捨てます。** 途中まで採用すると、
    /// 直前の点から意図しない線が伸びて絵が壊れます。
    func testIncompleteCurveIsDropped() {
        let path = CatPathParser.path(from: "M0 0 C1 2, 3 4 Z")
        XCTAssertEqual(elements(of: path), ["M(0.0,0.0)", "Z"])
    }

    // MARK: - 実データ

    /// 6状態すべてが、図形を持ち、余白込みの設計空間に収まっていることを確かめます。
    /// **描く前に「空だった」「はみ出していた」を検出する**ためのものです。
    func testEveryMoodHasShapesInsideCanvas() {
        for mood in CatMood.allCases {
            let shapes = CatArt.shapes(for: mood)
            XCTAssertFalse(shapes.isEmpty, "\(mood.rawValue) に図形がありません")

            for shape in shapes {
                let bounds = shape.path.boundingRect
                XCTAssertFalse(shape.path.isEmpty, "\(mood.rawValue) に空のパスがあります")
                XCTAssertGreaterThanOrEqual(bounds.minX, 0, "\(mood.rawValue) が左へはみ出しています")
                XCTAssertGreaterThanOrEqual(bounds.minY, 0, "\(mood.rawValue) が上へはみ出しています")
                XCTAssertLessThanOrEqual(bounds.maxX, CatArt.canvasSize, "\(mood.rawValue) が右へはみ出しています")
                XCTAssertLessThanOrEqual(bounds.maxY, CatArt.canvasSize, "\(mood.rawValue) が下へはみ出しています")
            }
        }
    }

    /// **どの状態にも体と金目の両方があること。** 片方だけになると、
    /// 黒一色の塊か、目だけが宙に浮いた絵になります。
    func testEveryMoodUsesBothInks() {
        for mood in CatMood.allCases {
            let inks = Set(CatArt.shapes(for: mood).map(\.ink))
            XCTAssertTrue(inks.contains(.body), "\(mood.rawValue) に体がありません")
            XCTAssertTrue(inks.contains(.accent), "\(mood.rawValue) に金目がありません")
        }
    }

    /// 状態ごとに違う絵であること。取り違えて同じデータを2箇所へ入れると、
    /// 画面では「なんとなく猫が変わらない」としか見えず原因に辿り着けません。
    func testMoodsAreDistinct() {
        let signatures = CatMood.allCases.map { mood in
            CatArt.shapes(for: mood).map { elements(of: $0.path).joined() }.joined()
        }
        XCTAssertEqual(Set(signatures).count, CatMood.allCases.count, "同じ絵の状態があります")
    }

    // MARK: - 補助

    /// パスの中身を、失敗時に読める文字列へ落とします。
    /// `Path` どうしの比較では、どこがどう違うのかが出ないためです。
    private func elements(of path: Path) -> [String] {
        var result: [String] = []
        path.forEach { element in
            switch element {
            case .move(let to):
                result.append("M\(point(to))")
            case .line(let to):
                result.append("L\(point(to))")
            case .quadCurve(let to, let control):
                result.append("Q\(point(to))|\(point(control))")
            case .curve(let to, let control1, let control2):
                result.append("C\(point(to))|\(point(control1))|\(point(control2))")
            case .closeSubpath:
                result.append("Z")
            }
        }
        return result
    }

    private func point(_ point: CGPoint) -> String {
        "(\(point.x),\(point.y))"
    }
}
