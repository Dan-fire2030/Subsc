import SwiftUI

/// ダッシュボードの先頭に座る相棒の黒猫です。
///
/// **金額に触れない位置に置きます。** 猫は主役ではなく、状況の要約を担うだけなので、
/// レポートカードの上に小さく座らせ、数字を読む動作を邪魔しません。
struct CatCompanionRow: View {
    let mood: CatMood

    /// 猫の大きさです。**レポートカードより明らかに小さく**して、主従を保ちます。
    private let size: CGFloat = 72

    var body: some View {
        HStack(spacing: 12) {
            CatCompanionView(mood: mood)
                .frame(width: size, height: size)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(spacing: 0) {
        ForEach(CatMood.allCases) { mood in
            CatCompanionRow(mood: mood)
        }
    }
    .padding()
    .background(BlackCatPalette.background)
}
