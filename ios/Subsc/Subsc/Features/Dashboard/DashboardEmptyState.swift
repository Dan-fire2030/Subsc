import SwiftUI

/// サブスクが1件も登録されていないときに一覧の代わりに出す案内です。
struct DashboardEmptyState: View {
    let addSubscription: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 14 : 18) {
            Image(systemName: "creditcard.and.123")
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .foregroundStyle(.blue.gradient)
                .frame(
                    width: dynamicTypeSize.isAccessibilitySize ? 60 : 72,
                    height: dynamicTypeSize.isAccessibilitySize ? 60 : 72
                )
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 22))
                .accessibilityHidden(true)

            VStack(spacing: 7) {
                Text(
                    dynamicTypeSize.isAccessibilitySize
                        ? "サブスクを管理"
                        : "サブスクをまとめて管理"
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
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: addSubscription) {
                Label(
                    dynamicTypeSize.isAccessibilitySize
                        ? "サブスクを追加"
                        : "最初のサブスクを追加",
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
        .glassSurface(cornerRadius: 24)
    }
}
