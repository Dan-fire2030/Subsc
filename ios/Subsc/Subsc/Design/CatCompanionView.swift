import SwiftUI

/// 相棒の猫です。気分に応じて表情（目・耳・小さな符号）が変わります。
///
/// **2026-10-15に黒猫からパステルの猫へ替えました。** 姿勢は1つに保ち、顔つきだけで
/// 気分を伝えます。形は `PastelCatArt`、気分と表情の対応は `CatExpression` が持ちます。
///
/// **文字は持ちません。** 金額を扱う画面でキャラクターが喋ると、事実と演出の区別が
/// つかなくなるためです。読み上げにだけ状態の説明を渡します。
struct CatCompanionView: View {
    let mood: CatMood

    /// 頬は体の上に半透明で重ね、色を足しすぎないようにします。
    private static let cheekOpacity = 0.6

    var body: some View {
        Canvas { context, size in
            // 設計空間（100）を、与えられた大きさへ収めます。
            let scale = min(size.width, size.height) / PastelCatArt.canvasSize
            let offset = CGPoint(
                x: (size.width - PastelCatArt.canvasSize * scale) / 2,
                y: (size.height - PastelCatArt.canvasSize * scale) / 2
            )
            context.translateBy(x: offset.x, y: offset.y)
            context.scaleBy(x: scale, y: scale)

            for shape in PastelCatArt.shapes(for: CatExpression(mood: mood)) {
                var layer = context
                if shape.ink == .cheek { layer.opacity = Self.cheekOpacity }
                layer.fill(shape.path, with: .color(Self.color(for: shape.ink)))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(mood.title)
    }

    private static func color(for ink: PastelCatInk) -> Color {
        switch ink {
        case .body: SubscPalette.catBody
        case .earInner: SubscPalette.catEarInner
        case .face: SubscPalette.catFace
        case .nose: SubscPalette.catNose
        case .cheek: SubscPalette.catCheek
        case .accent: SubscPalette.catAccent
        case .sweat: SubscPalette.catSweat
        }
    }
}

#Preview("ライト") {
    CatMoodGallery()
        .environment(\.colorScheme, .light)
}

#Preview("ダーク") {
    CatMoodGallery()
        .environment(\.colorScheme, .dark)
}

/// 6状態を並べて見比べるためのプレビュー用のビューです。
private struct CatMoodGallery: View {
    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(CatMood.allCases) { mood in
                    VStack(spacing: 6) {
                        CatCompanionView(mood: mood)
                            .frame(width: 110, height: 110)
                        Text(mood.title)
                            .font(.caption2)
                            .foregroundStyle(SubscPalette.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(10)
                    .background(SubscPalette.surface, in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .padding(16)
        }
        .background(SubscPalette.background)
    }
}
