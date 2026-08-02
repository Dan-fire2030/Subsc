import SwiftUI

/// 一覧に並ぶ借入1件です。
///
/// 費目の行（`SubscriptionRow`）と**同じ骨格**にしています。1本のリストへ混ざるため、
/// 高さや余白がずれると並びが不揃いに見えるためです。
/// 費目と違い、右側には月額ではなく**次回の返済額**を出します。
struct LoanRow: View {
    let loan: Loan
    let summary: LoanSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var accentColor: Color {
        ColorHex.color(from: CostType.loan.colorHex)
    }

    /// 大きな文字サイズでは方式と返済日を縦に積み、横幅の破綻を避けます。
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
            Image(systemName: CostType.loan.systemImage)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(accentColor, in: RoundedRectangle(cornerRadius: 11))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(loan.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    if summary.isCompleted {
                        StatusBadge(title: "完済")
                    } else if summary.missedCount > 0 {
                        StatusBadge(title: "滞納\(summary.missedCount)回")
                    }
                }

                metadataLayout {
                    LoanMethodBadge(title: loan.method.title, color: accentColor)
                    if let nextDueDate = summary.nextDueDate {
                        Text("\(nextDueDate.formatted(.dateTime.month().day()))返済")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else if !summary.isCompleted {
                        Text("返済予定が未設定")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Text("残高 \(summary.currentBalance.formatted(.currency(code: "JPY").precision(.fractionLength(0))))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 8)
            }

            VStack(
                alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing,
                spacing: 2
            ) {
                Text(summary.nextAmount, format: .currency(code: "JPY").precision(.fractionLength(0)))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text("次回返済")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .opacity(summary.isCompleted ? 0.62 : 1)
        .accessibilityElement(children: .combine)
    }
}

/// 完済・滞納を示すバッジです。費目行の「停止中」バッジと見た目を揃えています。
private struct StatusBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
    }
}

/// 返済方式のバッジです。費目行のカテゴリバッジと同じ作りにしています。
private struct LoanMethodBadge: View {
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
