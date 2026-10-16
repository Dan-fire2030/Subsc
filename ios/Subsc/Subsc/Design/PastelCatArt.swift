import SwiftUI

/// 猫の表情です。**目・耳・小さな符号の組み合わせで気分を出し分けます。**
///
/// 2026-10-15にパステルの図形の猫で始め、2026-10-16に**粘土の猫の絵**へ替えました。
/// 目と耳の違いは絵（5枚）が持ち、汗・きらめき・「！」・点はコードで重ねます。
/// 符号を絵に描き込まないのは、小さく表示したときに潰れないようにするためと、
/// 絵の枚数を減らすため（催促は「いつもどおり」の絵に「！」を重ねるだけ）です。
struct CatExpression: Hashable {
    enum Eyes: Hashable {
        /// 点の目。いつもの顔。
        case dot
        /// 目を細めて笑う。
        case smiling
        /// 目を見開く。
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

    /// 粘土の猫の絵の名前です（`Assets.xcassets` の `ClayCat*`）。
    ///
    /// **絵は目で選びます。** 耳の向きは目と一緒に絵に描かれている（困り顔だけ耳を伏せる）ので、
    /// 目が決まれば絵も1枚に決まります。絵は420px四方・背景透過で、5枚とも同じ枠で切り出しています。
    var imageName: String {
        switch eyes {
        case .dot: "ClayCatCalm"
        case .smiling: "ClayCatSmiling"
        case .wide: "ClayCatWide"
        case .worried: "ClayCatWorried"
        case .lookingAside: "ClayCatAside"
        }
    }
}

/// 猫に重ねる符号を塗り分ける役割です。色そのものは持たず、描画時に `SubscPalette` から引きます。
enum PastelCatInk: Hashable {
    /// 「！」・きらめき・案内の点。
    case accent
    case sweat
}

/// 猫に重ねる符号の図形1つです。
struct PastelCatShape {
    let ink: PastelCatInk
    let path: Path
}

/// 猫の絵に重ねる符号の形です。
///
/// **100×100の設計空間で持ち、絵と同じ枠に拡大して重ねます。** 粘土の猫は耳が枠の上の角近くまで
/// 届くため、「！」やきらめきは耳先より右上へ、汗は顔の右脇へ置いています。
enum PastelCatArt {
    static let canvasSize: CGFloat = 100

    static func accentShapes(for expression: CatExpression) -> [PastelCatShape] {
        switch expression.accent {
        case .none:
            return []
        case .sweat:
            var drop = Path()
            drop.move(to: CGPoint(x: 93, y: 34))
            drop.addQuadCurve(to: CGPoint(x: 97, y: 43), control: CGPoint(x: 98, y: 38))
            drop.addArc(center: CGPoint(x: 93, y: 43), radius: 4, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            drop.addQuadCurve(to: CGPoint(x: 93, y: 34), control: CGPoint(x: 88, y: 38))
            drop.closeSubpath()
            return [PastelCatShape(ink: .sweat, path: drop)]
        case .sparkle:
            return [PastelCatShape(ink: .accent, path: sparkle(center: CGPoint(x: 93, y: 9), radius: 6))]
        case .exclamation:
            var bar = Path(roundedRect: CGRect(x: 91.5, y: 3, width: 5, height: 13), cornerRadius: 2.5)
            bar.addPath(circle(CGPoint(x: 94, y: 21), radius: 2.6))
            return [PastelCatShape(ink: .accent, path: bar)]
        case .pointer:
            return [
                PastelCatShape(ink: .accent, path: circle(CGPoint(x: 90, y: 56), radius: 2.4)),
                PastelCatShape(ink: .accent, path: circle(CGPoint(x: 96.5, y: 56), radius: 1.8))
            ]
        }
    }

    // MARK: - 図形の道具

    private static func circle(_ center: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
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
}
