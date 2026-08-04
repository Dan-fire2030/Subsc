import SwiftUI

/// 一覧の1行です。サービス名・カテゴリ・更新日・メモ・月額換算をまとめて表示します。
struct SubscriptionRow: View {
    let subscription: Subscription
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 大きな文字サイズではカテゴリと更新日を縦に積み、横幅の破綻を避けます。
    private var metadataLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 6))
    }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 12))

        layout {
            Text(subscription.name.prefix(1).uppercased())
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(subscription.color, in: RoundedRectangle(cornerRadius: 11))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(subscription.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    if subscription.state == .paused {
                        Text("停止中")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
                metadataLayout {
                    CategoryBadge(title: subscription.category, color: subscription.color)
                    Text("\(subscription.renewalDate.formatted(.dateTime.month().day()))更新")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !subscription.notes.isEmpty {
                    Text(subscription.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 8)
            }

            VStack(
                alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing,
                spacing: 2
            ) {
                // **年払いは年額をそのまま出します。** レポートも更新月に全額を立てるので、
                // ここだけ1/12にすると、同じ費目が2つの額で見えてしまいます。
                Text(
                    subscription.billingCycle == .yearly
                        ? subscription.yenAmount
                        : subscription.monthlyYen,
                    format: .currency(code: "JPY").precision(.fractionLength(0))
                )
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                Text(subscription.billingCycle == .yearly ? "年額" : "月額")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .opacity(subscription.state == .paused ? 0.62 : 1)
        .accessibilityElement(children: .combine)
    }
}

/// 一覧行でカテゴリを示すバッジです。
///
/// カラーは利用者が自由に選べるため、淡い色でも読めるように文字色は `.secondary` に固定し、
/// 色は小さなドットでだけ示します。カプセルの見た目は「停止中」バッジと揃えています。
private struct CategoryBadge: View {
    let title: String
    let color: Color

    /// ドットは文字サイズに追従させます。固定サイズだと拡大時に見えなくなるためです。
    @ScaledMetric(relativeTo: .caption2) private var dotSize: CGFloat = 6

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: dotSize, height: dotSize)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.quaternary, in: Capsule())
    }
}
