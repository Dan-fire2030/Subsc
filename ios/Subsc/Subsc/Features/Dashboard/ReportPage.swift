import SwiftUI

/// ページャの1ページ、つまり1期間ぶんの表示です。
/// 合計額のヘッダーとチャート枠を持ち、登録がない期間は代わりに案内を出します。
struct ReportPage: View {
    let report: PaymentReport
    let periodLabel: String
    let reduceMotion: Bool
    let costTypeFilter: CostTypeFilter
    let period: ReportPeriod
    @Environment(ThemeStore.self) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var chartHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 340 : 130
    }

    /// 合計の下に出す内訳の説明です。
    ///
    /// 見込みが混ざっているときは合計が確定額ではないので、その旨をここで断ります。
    /// 断らないと、実績として記録済みの金額だと誤解されます。
    private var entriesDescription: String {
        let base = "\(report.entries.count)件の費目"
        return report.entries.contains(where: \.isEstimated) ? "\(base)・見込みを含む" : base
    }

    var body: some View {
        VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 14 : 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(periodLabel)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))

                Text(report.total, format: .currency(code: "JPY").precision(.fractionLength(0)))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .contentTransition(.numericText(value: report.total))

                Text(entriesDescription)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.84))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 14 : 12)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 11 : 8)
            .background(
                .black.opacity(0.16),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.58), .white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }

            Group {
                if report.entries.isEmpty {
                    VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 12 : 8) {
                        Image(systemName: "chart.bar")
                            .font(dynamicTypeSize.isAccessibilitySize ? .title : .title2)
                        Text(
                            dynamicTypeSize.isAccessibilitySize
                                ? "登録はありません"
                                : "この期間の利用データはありません"
                        )
                        .font(
                            dynamicTypeSize.isAccessibilitySize
                                ? .body.weight(.semibold)
                                : .callout.weight(.semibold)
                        )
                        .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("この期間の利用コストはありません")
                } else {
                    chart
                }
            }
            .frame(maxWidth: .infinity, minHeight: chartHeight, maxHeight: chartHeight)
            .padding(dynamicTypeSize.isAccessibilitySize ? 10 : 8)
            .background(
                .black.opacity(0.14),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var chart: some View {
        switch theme.chartStyle {
        case .bar:
            StackedBarChart(
                entries: report.entries,
                costTypeFilter: costTypeFilter,
                period: period,
                reduceMotion: reduceMotion
            )
        case .ring:
            ConcentricRingChart(
                entries: report.entries,
                costTypeFilter: costTypeFilter,
                period: period,
                reduceMotion: reduceMotion
            )
        case .bubble, .column:
            GlassBarChart(
                entries: report.entries,
                reduceMotion: reduceMotion
            )
        }
    }
}
