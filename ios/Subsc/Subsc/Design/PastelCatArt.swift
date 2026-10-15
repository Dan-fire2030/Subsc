import SwiftUI

/// 猫の表情です。**姿勢は変えず、目・耳・小さな符号だけで気分を出し分けます**（2026-10-15）。
///
/// 前の黒猫は気分ごとにシルエットを描き分けていましたが、パステルの猫は
/// 「さりげなく添える」役割なので、形は1つに保ち、顔つきだけを変えます。
/// 対応表をここに閉じ込め、どの気分がどの顔かをテストで縛れるようにしています。
struct CatExpression: Hashable {
    enum Eyes: Hashable {
        /// 点の目。いつもの顔。
        case dot
        /// 目を細めて笑う。
        case smiling
        /// 目を見開く（ハイライト入り）。
        case wide
        /// 小さな目と困り眉。
        case worried
        /// 横を見る。
        case lookingAside
    }

    enum Ears: Hashable {
        case up
        /// 耳を伏せる。
        case droop
    }

    /// 顔の横に添える小さな符号です。
    enum Accent: Hashable {
        case none
        case sweat
        case sparkle
        case exclamation
        /// 横へ並ぶ点。「こっちだよ」と方向を示します。
        case pointer
    }

    let eyes: Eyes
    let ears: Ears
    let accent: Accent

    init(eyes: Eyes, ears: Ears, accent: Accent) {
        self.eyes = eyes
        self.ears = ears
        self.accent = accent
    }

    init(mood: CatMood) {
        switch mood {
        case .calm: self.init(eyes: .dot, ears: .up, accent: .none)
        case .worried: self.init(eyes: .worried, ears: .droop, accent: .sweat)
        case .pleased: self.init(eyes: .smiling, ears: .up, accent: .sparkle)
        case .watching: self.init(eyes: .wide, ears: .up, accent: .none)
        case .nudging: self.init(eyes: .dot, ears: .up, accent: .exclamation)
        case .guiding: self.init(eyes: .lookingAside, ears: .up, accent: .pointer)
        }
    }
}

/// 猫の絵を塗り分ける役割です。色そのものは持たず、描画時に `SubscPalette` から引きます。
enum PastelCatInk: Hashable {
    case body
    case earInner
    /// 目・眉・口元。
    case face
    case nose
    case cheek
    /// 「！」・きらめき・案内の点。
    case accent
    case sweat
}

/// 猫の絵を構成する図形1つです。
struct PastelCatShape {
    let ink: PastelCatInk
    let path: Path
}

/// パステルの猫の形です。
///
/// **100×100の設計空間で持ち、表示時に拡大します。** 丸と角の丸い三角だけで描くので、
/// 小さく表示しても潰れません。下端の前足は、カードの縁に手をかけて「のぞく」ときに
/// 縁へ重なる位置にあります。
enum PastelCatArt {
    static let canvasSize: CGFloat = 100

    /// 表情に応じた図形の並びです。**奥から手前の順**に並びます。
    static func shapes(for expression: CatExpression) -> [PastelCatShape] {
        var shapes: [PastelCatShape] = []
        shapes += ears(expression.ears)
        shapes.append(PastelCatShape(ink: .body, path: Path(ellipseIn: Geometry.head)))
        shapes += Geometry.paws.map { PastelCatShape(ink: .body, path: Path(ellipseIn: $0)) }
        shapes += Geometry.cheeks.map { PastelCatShape(ink: .cheek, path: circle($0, radius: Geometry.cheekRadius)) }
        shapes += eyes(expression.eyes)
        shapes.append(PastelCatShape(ink: .nose, path: nose()))
        shapes += accent(expression.accent)
        return shapes
    }

    // MARK: - 部品

    private static func ears(_ ears: CatExpression.Ears) -> [PastelCatShape] {
        let outer = ears == .up ? Geometry.earsUp : Geometry.earsDroop
        let inner = ears == .up ? Geometry.innerEarsUp : Geometry.innerEarsDroop
        return outer.map { PastelCatShape(ink: .body, path: roundedTriangle($0, apexIndex: 1)) }
            + inner.map { PastelCatShape(ink: .earInner, path: roundedTriangle($0, apexIndex: 1)) }
    }

    private static func eyes(_ eyes: CatExpression.Eyes) -> [PastelCatShape] {
        let centers = Geometry.eyeCenters
        switch eyes {
        case .dot:
            return centers.map { PastelCatShape(ink: .face, path: circle($0, radius: 4)) }
        case .wide:
            return centers.flatMap { center in
                [
                    PastelCatShape(ink: .face, path: circle(center, radius: 5.5)),
                    PastelCatShape(ink: .body, path: circle(CGPoint(x: center.x + 1.6, y: center.y - 1.6), radius: 1.6))
                ]
            }
        case .worried:
            let pupils = centers.map {
                PastelCatShape(ink: .face, path: circle(CGPoint(x: $0.x, y: $0.y + 1), radius: 3.2))
            }
            // 眉は内側を持ち上げて「困り顔」にします。
            let brows = [
                line(from: CGPoint(x: 32, y: 46.5), to: CGPoint(x: 42, y: 43.5)),
                line(from: CGPoint(x: 58, y: 43.5), to: CGPoint(x: 68, y: 46.5))
            ].map { PastelCatShape(ink: .face, path: $0) }
            return pupils + brows
        case .smiling:
            return centers.map { center in
                var arc = Path()
                arc.addArc(
                    center: CGPoint(x: center.x, y: center.y + 2),
                    radius: 4.5,
                    startAngle: .degrees(200),
                    endAngle: .degrees(340),
                    clockwise: false
                )
                return PastelCatShape(ink: .face, path: stroked(arc, width: 2.4))
            }
        case .lookingAside:
            return centers.map {
                PastelCatShape(ink: .face, path: circle(CGPoint(x: $0.x + 3.5, y: $0.y), radius: 4))
            }
        }
    }

    private static func accent(_ accent: CatExpression.Accent) -> [PastelCatShape] {
        switch accent {
        case .none:
            return []
        case .sweat:
            var drop = Path()
            drop.move(to: CGPoint(x: 87, y: 26))
            drop.addQuadCurve(to: CGPoint(x: 91, y: 35), control: CGPoint(x: 92, y: 30))
            drop.addArc(center: CGPoint(x: 87, y: 35), radius: 4, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            drop.addQuadCurve(to: CGPoint(x: 87, y: 26), control: CGPoint(x: 82, y: 30))
            drop.closeSubpath()
            return [PastelCatShape(ink: .sweat, path: drop)]
        case .sparkle:
            return [PastelCatShape(ink: .accent, path: sparkle(center: CGPoint(x: 87, y: 22), radius: 7))]
        case .exclamation:
            var bar = Path(roundedRect: CGRect(x: 84.5, y: 6, width: 5, height: 15), cornerRadius: 2.5)
            bar.addPath(circle(CGPoint(x: 87, y: 26), radius: 2.6))
            return [PastelCatShape(ink: .accent, path: bar)]
        case .pointer:
            return [
                PastelCatShape(ink: .accent, path: circle(CGPoint(x: 90, y: 56), radius: 2.4)),
                PastelCatShape(ink: .accent, path: circle(CGPoint(x: 96.5, y: 56), radius: 1.8))
            ]
        }
    }

    private static func nose() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 47.5, y: 63))
        path.addLine(to: CGPoint(x: 52.5, y: 63))
        path.addLine(to: CGPoint(x: 50, y: 66))
        path.closeSubpath()
        return path
    }

    // MARK: - 図形の道具

    private static func circle(_ center: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    private static func line(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return stroked(path, width: 2.4)
    }

    private static func stroked(_ path: Path, width: CGFloat) -> Path {
        path.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    /// 頂点だけを丸めた三角形です。耳の先が尖りすぎると、パステルの柔らかさから浮くためです。
    private static func roundedTriangle(_ points: [CGPoint], apexIndex: Int) -> Path {
        let apex = points[apexIndex]
        let before = points[(apexIndex + 2) % 3]
        let after = points[(apexIndex + 1) % 3]
        let rounding: CGFloat = 0.22
        let entry = CGPoint(x: apex.x + (before.x - apex.x) * rounding, y: apex.y + (before.y - apex.y) * rounding)
        let exit = CGPoint(x: apex.x + (after.x - apex.x) * rounding, y: apex.y + (after.y - apex.y) * rounding)

        var path = Path()
        path.move(to: before)
        path.addLine(to: entry)
        path.addQuadCurve(to: exit, control: apex)
        path.addLine(to: after)
        path.closeSubpath()
        return path
    }

    private static func sparkle(center: CGPoint, radius: CGFloat) -> Path {
        let waist = radius * 0.32
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - radius))
        path.addQuadCurve(to: CGPoint(x: center.x + radius, y: center.y), control: CGPoint(x: center.x + waist, y: center.y - waist))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y + radius), control: CGPoint(x: center.x + waist, y: center.y + waist))
        path.addQuadCurve(to: CGPoint(x: center.x - radius, y: center.y), control: CGPoint(x: center.x - waist, y: center.y + waist))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius), control: CGPoint(x: center.x - waist, y: center.y - waist))
        path.closeSubpath()
        return path
    }

    /// 設計空間（100×100）での位置です。キャンバスのデザイン案（56×44）を拡大して写しています。
    private enum Geometry {
        static let head = CGRect(x: 16, y: 29, width: 68, height: 54)
        static let paws = [
            CGRect(x: 25, y: 76, width: 18, height: 13),
            CGRect(x: 57, y: 76, width: 18, height: 13)
        ]
        static let eyeCenters = [CGPoint(x: 38, y: 54), CGPoint(x: 62, y: 54)]
        static let cheeks = [CGPoint(x: 29, y: 64), CGPoint(x: 71, y: 64)]
        static let cheekRadius: CGFloat = 4.6

        /// 耳は「付け根・先・付け根」の順です（先＝添字1）。
        static let earsUp = [
            [CGPoint(x: 20, y: 46), CGPoint(x: 25, y: 13), CGPoint(x: 46, y: 31)],
            [CGPoint(x: 54, y: 31), CGPoint(x: 75, y: 13), CGPoint(x: 80, y: 46)]
        ]
        static let innerEarsUp = [
            [CGPoint(x: 27, y: 37), CGPoint(x: 28.5, y: 22), CGPoint(x: 39, y: 31)],
            [CGPoint(x: 61, y: 31), CGPoint(x: 71.5, y: 22), CGPoint(x: 73, y: 37)]
        ]
        /// 伏せた耳は、先を外側へ倒します。
        static let earsDroop = [
            [CGPoint(x: 18, y: 50), CGPoint(x: 7, y: 24), CGPoint(x: 42, y: 34)],
            [CGPoint(x: 58, y: 34), CGPoint(x: 93, y: 24), CGPoint(x: 82, y: 50)]
        ]
        static let innerEarsDroop = [
            [CGPoint(x: 21, y: 43), CGPoint(x: 14, y: 30), CGPoint(x: 33, y: 37)],
            [CGPoint(x: 67, y: 37), CGPoint(x: 86, y: 30), CGPoint(x: 79, y: 43)]
        ]
    }
}
