import SwiftUI

/// 猫の絵を塗り分ける2色の役割です。
///
/// **色そのものを持ちません。** 元のSVGが黒と金の2色でできているという事実だけを残し、
/// 実際の値は描画時に渡します。ライトとダークで色が変わるためです。
enum CatInk {
    /// 体・耳・瞳孔など、猫そのもの。
    case body
    /// 目と、猫に添える符号（汗・きらめき・「！」・案内の点）。
    case accent
}

/// 猫の絵を構成する図形1つです。
struct CatShape {
    let ink: CatInk
    let path: Path
}

/// 相棒の黒猫の形です。
///
/// **210×210の設計空間で持ち、表示時に拡大します。** 解像度に依存せず、
/// 大きさを変えても比が崩れません。耳や尻尾の逃げ場を含めた寸法です。
///
/// **形は `CatArtworkData` が持ちます。** ここは「どの状態がどの図形の並びか」と
/// 「どう塗るか」だけを持ちます。図形は `.output/design-system/brand/cat-*.svg` から
/// 機械的に写したもので、手で座標を置くのをやめた経緯は `CatArtworkData` に書いています。
///
/// **輪郭線を持たせず、塗りのシルエットだけで成立させています。** 小さく表示しても
/// 潰れず、ライトでは墨の影として読めます。
enum CatArt {
    /// 設計空間の一辺です。元のSVGの `viewBox` と一致させています。
    static let canvasSize: CGFloat = 210

    /// 状態に応じた図形の並びです。**手前から奥ではなく、奥から手前の順**に並びます。
    static func shapes(for mood: CatMood) -> [CatShape] {
        switch mood {
        case .calm: CatArtworkData.calm
        case .worried: CatArtworkData.worried
        case .pleased: CatArtworkData.pleased
        case .watching: CatArtworkData.watching
        case .nudging: CatArtworkData.nudging
        case .guiding: CatArtworkData.guiding
        }
    }

    /// 状態に応じた猫を描きます。
    static func draw(
        mood: CatMood,
        in context: inout GraphicsContext,
        cat: Color,
        eye: Color
    ) {
        for shape in shapes(for: mood) {
            context.fill(shape.path, with: .color(shape.ink == .body ? cat : eye))
        }
    }
}
