import SwiftUI

/// 相棒の猫です。気分に応じて表情（目・耳・小さな符号）が変わります。
///
/// **2026-10-16に図形の猫から粘土の猫の絵へ替えました。** 目と耳の違いは絵（`CatExpression.imageName`）が持ち、
/// 汗・きらめき・「！」・点は `PastelCatArt` の図形をコードで重ねます。
/// 絵は1枚で両モードに使います（粘土の質感は暗い地でも明るい地でも沈まないため）。
///
/// **文字は持ちません。** 金額を扱う画面でキャラクターが喋ると、事実と演出の区別が
/// つかなくなるためです。読み上げにだけ状態の説明を渡します。
struct CatCompanionView: View {
    let mood: CatMood

    var body: some View {
        let expression = CatExpression(mood: mood)
        ZStack {
            Image(expression.imageName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
            Canvas { context, size in
                // 設計空間（100）を、絵と同じ枠へ収めます。
                let scale = min(size.width, size.height) / PastelCatArt.canvasSize
                context.translateBy(
                    x: (size.width - PastelCatArt.canvasSize * scale) / 2,
                    y: (size.height - PastelCatArt.canvasSize * scale) / 2
                )
                context.scaleBy(x: scale, y: scale)
                for shape in PastelCatArt.accentShapes(for: expression) {
                    context.fill(shape.path, with: .color(Self.color(for: shape.ink)))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(mood.title)
    }

    private static func color(for ink: PastelCatInk) -> Color {
        switch ink {
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
