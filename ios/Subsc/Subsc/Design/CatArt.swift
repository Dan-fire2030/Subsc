import SwiftUI

/// 相棒の黒猫の形です。
///
/// **200×200の設計空間で持ち、表示時に拡大します。** 解像度に依存せず、
/// 大きさを変えても線の太さの比が崩れません。
///
/// **輪郭線を持たせず、塗りのシルエットだけで成立させています。** 小さく表示しても
/// 潰れず、ライトでは墨の影として読めます。口・鼻・ひげは描きません（小さくしたとき
/// 最初に潰れるのがこの3つで、潰れた瞬間に「汚れた円」に見えるためです）。
///
/// **注意：体と同じ色の部品を体に重ねると、輪郭が融合して消えます。**
/// 前足はシルエットの外まで振り出してください（実際に2度この罠を踏みました）。
enum CatArt {
    /// 設計空間の一辺です。
    static let designSize: CGFloat = 200
    /// 余白です。耳や尻尾が設計空間から少しはみ出すため、その逃げ場です。
    static let margin: CGFloat = 5
    /// 余白を含めた描画領域の一辺です。
    static let canvasSize = designSize + margin * 2

    /// 状態に応じた猫を描きます。
    static func draw(
        mood: CatMood,
        in context: inout GraphicsContext,
        cat: Color,
        eye: Color
    ) {
        switch mood {
        case .calm: drawCalm(&context, cat, eye)
        case .worried: drawWorried(&context, cat, eye)
        case .pleased: drawPleased(&context, cat, eye)
        case .watching: drawWatching(&context, cat, eye)
        case .nudging: drawNudging(&context, cat, eye)
        case .guiding: drawGuiding(&context, cat, eye)
        }
    }

    // MARK: - 状態ごとの姿

    /// 基準の姿勢。座って前を向きます。
    private static func drawCalm(_ ctx: inout GraphicsContext, _ cat: Color, _ eye: Color) {
        stroke(&ctx, curve([(148, 178), (182, 178), (190, 148), (172, 130)]), cat, 13)
        fill(&ctx, dome(left: 52, right: 148, top: 114, bottom: 182, shoulder: 134), cat)
        drawUprightEars(&ctx, cat, eye)
        fill(&ctx, circle(100, 88, 43), cat)
        fill(&ctx, ellipse(85, 88, 6, 9), eye)
        fill(&ctx, ellipse(115, 88, 6, 9), eye)
    }

    /// うずくまり、耳を真横へ倒し、目を見開きます。金色の汗を添えます。
    private static func drawWorried(_ ctx: inout GraphicsContext, _ cat: Color, _ eye: Color) {
        fill(&ctx, dome(left: 34, right: 166, top: 132, bottom: 184, shoulder: 148), cat)
        fill(&ctx, polygon([(62, 108), (22, 92), (68, 84)]), cat)
        fill(&ctx, polygon([(138, 108), (178, 92), (132, 84)]), cat)
        fill(&ctx, polygon([(64, 102), (36, 92), (66, 88)]), eye.opacity(innerEarOpacity))
        fill(&ctx, polygon([(136, 102), (164, 92), (134, 88)]), eye.opacity(innerEarOpacity))
        fill(&ctx, circle(100, 112, 44), cat)
        fill(&ctx, ellipse(82, 114, 12, 14), eye)
        fill(&ctx, ellipse(118, 114, 12, 14), eye)
        fill(&ctx, ellipse(82, 116, 5, 7), cat)
        fill(&ctx, ellipse(118, 116, 5, 7), cat)
        stroke(&ctx, curve([(164, 182), (128, 196), (78, 194), (48, 182)]), cat, 13)
        // 汗は三角と円の合成です。しずくの形を1本のパスで書くより、意図が読めます。
        fill(&ctx, polygon([(170, 58), (183, 88), (157, 88)]), eye)
        fill(&ctx, circle(170, 88, 13), eye)
    }

    /// 胸を張り、目を閉じて笑い、尻尾を高く立てます。きらめきを添えます。
    private static func drawPleased(_ ctx: inout GraphicsContext, _ cat: Color, _ eye: Color) {
        stroke(&ctx, curve([(142, 168), (176, 158), (184, 104), (158, 80)]), cat, 13)
        fill(&ctx, dome(left: 58, right: 142, top: 104, bottom: 182, shoulder: 126), cat)
        fill(&ctx, polygon([(70, 54), (66, 10), (104, 38)]), cat)
        fill(&ctx, polygon([(130, 54), (134, 10), (96, 38)]), cat)
        fill(&ctx, polygon([(76, 48), (74, 22), (96, 39)]), eye.opacity(innerEarOpacity))
        fill(&ctx, polygon([(124, 48), (126, 22), (104, 39)]), eye.opacity(innerEarOpacity))
        fill(&ctx, circle(100, 80, 43), cat)
        stroke(&ctx, curve([(76, 84), (81, 74), (89, 74), (94, 84)]), eye, 8)
        stroke(&ctx, curve([(106, 84), (111, 74), (119, 74), (124, 84)]), eye, 8)
        fill(&ctx, sparkle(center: (40, 68), radius: 16), eye)
        fill(&ctx, sparkle(center: (166, 48), radius: 12), eye.opacity(0.75))
    }

    /// 細く高く背を伸ばし、瞳孔を縦に細め、尻尾を直立させます。
    private static func drawWatching(_ ctx: inout GraphicsContext, _ cat: Color, _ eye: Color) {
        stroke(&ctx, curve([(132, 178), (160, 170), (172, 110), (168, 58)]), cat, 13)
        fill(&ctx, dome(left: 74, right: 126, top: 88, bottom: 184, shoulder: 108), cat)
        fill(&ctx, polygon([(74, 44), (72, -4), (106, 28)]), cat)
        fill(&ctx, polygon([(126, 44), (128, -4), (94, 28)]), cat)
        fill(&ctx, polygon([(80, 38), (79, 10), (98, 28)]), eye.opacity(innerEarOpacity))
        fill(&ctx, polygon([(120, 38), (121, 10), (102, 28)]), eye.opacity(innerEarOpacity))
        fill(&ctx, circle(100, 70, 40), cat)
        fill(&ctx, circle(86, 70, 12), eye)
        fill(&ctx, circle(114, 70, 12), eye)
        fill(&ctx, ellipse(86, 70, 3, 10), cat)
        fill(&ctx, ellipse(114, 70, 3, 10), cat)
    }

    /// 立ち上がって両手を上げ、頭を傾けます。金色の「！」を添えます。
    private static func drawNudging(_ ctx: inout GraphicsContext, _ cat: Color, _ eye: Color) {
        stroke(&ctx, curve([(128, 180), (158, 186), (170, 168), (164, 148)]), cat, 13)
        fill(&ctx, dome(left: 72, right: 128, top: 110, bottom: 184, shoulder: 124), cat)
        // 頭は cx=100・r=42（x58〜142）。腕の先をこの範囲へ入れると輪郭が融合して消えます。
        stroke(&ctx, curve([(80, 138), (60, 132), (46, 118), (40, 100)]), cat, 14)
        stroke(&ctx, curve([(120, 138), (140, 132), (154, 118), (160, 100)]), cat, 14)
        fill(&ctx, circle(38, 96, 11), cat)
        fill(&ctx, circle(162, 96, 11), cat)

        let tilt = rotation(degrees: -16, around: (100, 84))
        fill(&ctx, polygon([(70, 58), (66, 16), (104, 42)]).applying(tilt), cat)
        fill(&ctx, polygon([(130, 58), (134, 16), (96, 42)]).applying(tilt), cat)
        fill(&ctx, polygon([(76, 52), (74, 28), (96, 43)]).applying(tilt), eye.opacity(innerEarOpacity))
        fill(&ctx, polygon([(124, 52), (126, 28), (104, 43)]).applying(tilt), eye.opacity(innerEarOpacity))
        fill(&ctx, circle(100, 84, 42).applying(tilt), cat)
        fill(&ctx, ellipse(85, 84, 7, 10).applying(tilt), eye)
        fill(&ctx, ellipse(115, 84, 7, 10).applying(tilt), eye)

        fill(&ctx, Path(roundedRect: CGRect(x: 168, y: 30, width: 9, height: 30), cornerRadius: 4.5), eye)
        fill(&ctx, circle(172.5, 70, 5), eye)
    }

    /// 横を向いて前足で指し示します。金色の点が続きます。
    private static func drawGuiding(_ ctx: inout GraphicsContext, _ cat: Color, _ eye: Color) {
        stroke(&ctx, curve([(46, 178), (14, 176), (8, 148), (26, 130)]), cat, 13)
        fill(&ctx, dome(left: 40, right: 126, top: 118, bottom: 182, shoulder: 138), cat)
        stroke(&ctx, curve([(112, 168), (134, 164), (148, 158), (160, 150)]), cat, 14)
        fill(&ctx, circle(162, 149, 9), cat)
        fill(&ctx, polygon([(56, 66), (52, 24), (90, 50)]), cat)
        fill(&ctx, polygon([(118, 66), (122, 24), (84, 50)]), cat)
        fill(&ctx, polygon([(62, 60), (60, 36), (82, 51)]), eye.opacity(innerEarOpacity))
        fill(&ctx, polygon([(112, 60), (114, 36), (92, 51)]), eye.opacity(innerEarOpacity))
        fill(&ctx, circle(87, 92, 43), cat)
        fill(&ctx, ellipse(98, 92, 6, 9), eye)
        fill(&ctx, ellipse(122, 92, 6, 9), eye)
        fill(&ctx, circle(176, 126, 6), eye)
        fill(&ctx, circle(190, 112, 4), eye.opacity(0.65))
        fill(&ctx, circle(201, 101, 2.5), eye.opacity(0.4))
    }

    // MARK: - 共通の部品

    /// 立った耳と、その内側です。座り姿の3状態で共通です。
    private static func drawUprightEars(_ ctx: inout GraphicsContext, _ cat: Color, _ eye: Color) {
        fill(&ctx, polygon([(68, 62), (64, 20), (102, 46)]), cat)
        fill(&ctx, polygon([(132, 62), (136, 20), (98, 46)]), cat)
        fill(&ctx, polygon([(74, 56), (72, 32), (94, 47)]), eye.opacity(innerEarOpacity))
        fill(&ctx, polygon([(126, 56), (128, 32), (106, 47)]), eye.opacity(innerEarOpacity))
    }

    /// 耳の内側の濃さです。強すぎると顔の重心が耳へ上がります。
    private static let innerEarOpacity: Double = 0.28

    // MARK: - 図形の組み立て

    /// 座った体です。左右の裾から肩へ立ち上がり、頭の下で丸くつながります。
    private static func dome(
        left: CGFloat,
        right: CGFloat,
        top: CGFloat,
        bottom: CGFloat,
        shoulder: CGFloat
    ) -> Path {
        let center = (left + right) / 2
        let inset = (right - left) * 0.21
        var path = Path()
        path.move(to: CGPoint(x: left, y: bottom))
        path.addCurve(
            to: CGPoint(x: center, y: top),
            control1: CGPoint(x: left, y: shoulder),
            control2: CGPoint(x: left + inset, y: top)
        )
        path.addCurve(
            to: CGPoint(x: right, y: bottom),
            control1: CGPoint(x: right - inset, y: top),
            control2: CGPoint(x: right, y: shoulder)
        )
        path.closeSubpath()
        return path
    }

    private static func circle(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat) -> Path {
        ellipse(x, y, radius, radius)
    }

    private static func ellipse(
        _ x: CGFloat,
        _ y: CGFloat,
        _ radiusX: CGFloat,
        _ radiusY: CGFloat
    ) -> Path {
        Path(ellipseIn: CGRect(
            x: x - radiusX,
            y: y - radiusY,
            width: radiusX * 2,
            height: radiusY * 2
        ))
    }

    private static func polygon(_ points: [(CGFloat, CGFloat)]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: first.0, y: first.1))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.0, y: point.1))
        }
        path.closeSubpath()
        return path
    }

    /// 3次ベジエ1本です。始点・制御点2つ・終点の順で渡します。
    private static func curve(_ points: [(CGFloat, CGFloat)]) -> Path {
        var path = Path()
        guard points.count == 4 else { return path }
        path.move(to: CGPoint(x: points[0].0, y: points[0].1))
        path.addCurve(
            to: CGPoint(x: points[3].0, y: points[3].1),
            control1: CGPoint(x: points[1].0, y: points[1].1),
            control2: CGPoint(x: points[2].0, y: points[2].1)
        )
        return path
    }

    /// 4方向へ尖ったきらめきです。
    private static func sparkle(center: (CGFloat, CGFloat), radius: CGFloat) -> Path {
        let (x, y) = center
        let waist = radius * 0.26
        return polygon([
            (x, y - radius), (x + waist, y - waist), (x + radius, y), (x + waist, y + waist),
            (x, y + radius), (x - waist, y + waist), (x - radius, y), (x - waist, y - waist)
        ])
    }

    private static func rotation(degrees: CGFloat, around point: (CGFloat, CGFloat)) -> CGAffineTransform {
        CGAffineTransform(translationX: point.0, y: point.1)
            .rotated(by: degrees * .pi / 180)
            .translatedBy(x: -point.0, y: -point.1)
    }

    private static func fill(_ context: inout GraphicsContext, _ path: Path, _ color: Color) {
        context.fill(path, with: .color(color))
    }

    private static func stroke(
        _ context: inout GraphicsContext,
        _ path: Path,
        _ color: Color,
        _ width: CGFloat
    ) {
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }
}
