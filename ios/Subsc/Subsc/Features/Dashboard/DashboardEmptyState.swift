import SwiftUI

/// サブスクが1件も登録されていないときに一覧の代わりに出す案内です。
struct DashboardEmptyState: View {
    let addSubscription: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 14 : 18) {
            // **記号ではなく相棒の猫に案内させます（2026-08-06）。**
            // 初回起動でいちばん最初に出る画面なので、ここで世界観に触れてもらいます。
            // 猫は横を向いて「追加」の方向を指し示します（`CatMood.guiding`）。
            CatCompanionView(mood: .guiding)
                .frame(
                    width: dynamicTypeSize.isAccessibilitySize ? 110 : 140,
                    height: dynamicTypeSize.isAccessibilitySize ? 110 : 140
                )

            VStack(spacing: 7) {
                Text(
                    dynamicTypeSize.isAccessibilitySize
                        ? "固定費を管理"
                        : "固定費をまとめて管理"
                )
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    dynamicTypeSize.isAccessibilitySize
                        ? "料金と更新日を登録して、利用コストと次回更新を確認できます。"
                        : "料金と更新日を登録すると、毎月の利用コストと次回更新をひと目で確認できます。"
                )
                    .font(.body)
                    .foregroundStyle(BlackCatPalette.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: addSubscription) {
                Label(
                    dynamicTypeSize.isAccessibilitySize
                        ? "費目を追加"
                        : "最初の費目を追加",
                    systemImage: "plus"
                )
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .prominentGlassButton()
            .controlSize(.large)
            .accessibilityIdentifier("empty-state-add-subscription-button")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 16 : 24)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 22 : 30)
        // カードは操作部品ではないので、ここもマットの面にします。
        .background(
            BlackCatPalette.surface,
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
    }
}
