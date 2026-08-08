import SwiftUI

/// 相棒の黒猫です。状態に応じて姿勢ごと変わります。
///
/// **文字は持ちません。** 金額を扱う画面でキャラクターが喋ると、事実と演出の区別が
/// つかなくなるためです。読み上げにだけ状態の説明を渡します。
struct CatCompanionView: View {
    let mood: CatMood

    var body: some View {
        Canvas { context, size in
            // 設計空間（210）を、与えられた大きさへ収めます。
            // 耳や尻尾の逃げ場は設計空間の中に含まれているため、余白は足しません。
            let scale = min(size.width, size.height) / CatArt.canvasSize
            context.scaleBy(x: scale, y: scale)
            CatArt.draw(
                mood: mood,
                in: &context,
                cat: BlackCatPalette.cat,
                eye: BlackCatPalette.catEye
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(mood.title)
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
                            .foregroundStyle(BlackCatPalette.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(10)
                    .background(BlackCatPalette.surface, in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .padding(16)
        }
        .background(BlackCatPalette.background)
    }
}
