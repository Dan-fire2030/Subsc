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

    /// 背後へ敷く面のぼかし半径です。**設計空間（210）の単位**なので、
    /// 表示を大きくしても小さくしても、猫に対する滲みの比は変わりません。
    private static let haloBlurRadius: CGFloat = 9

    /// 状態に応じた猫を描きます。
    ///
    /// `halo` を渡すと、**同じ形をぼかして背後へ一度敷いてから**猫を描きます。
    /// 円い面ではなく猫の形そのものを使うのは、位置や大きさの定数を持たずに済み、
    /// どの状態でもシルエットに沿って縁だけが淡く光るためです。
    /// 敷く必要が無いモード（ライト）では `nil` を渡し、描画ごと省きます。
    static func draw(
        mood: CatMood,
        in context: inout GraphicsContext,
        cat: Color,
        eye: Color,
        halo: Color? = nil
    ) {
        let shapes = shapes(for: mood)

        if let halo {
            // **体だけを敷きます。** 目や符号まで敷くと、金色の周りが二重に光ります。
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: haloBlurRadius))
                for shape in shapes where shape.ink == .body {
                    layer.fill(shape.path, with: .color(halo))
                }
            }
        }

        for shape in shapes {
            context.fill(shape.path, with: .color(shape.ink == .body ? cat : eye))
        }
    }
}
