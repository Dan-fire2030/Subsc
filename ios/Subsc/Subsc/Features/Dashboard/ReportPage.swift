import SwiftUI

/// ページャの1ページ、つまり1期間ぶんの表示です。
/// 合計額のヘッダーとチャート枠を持ち、登録がない期間は代わりに案内を出します。
struct ReportPage: View {
    let report: PaymentReport
    let periodLabel: String
    let reduceMotion: Bool
    let costTypeFilter: CostTypeFilter
    let period: ReportPeriod
    /// 相棒の黒猫です。**今の期間のページにだけ**渡します。
    /// 過去や先の月のページに出すと、いまの状況を語る猫が過去を語っているように見えます。
    let catMood: CatMood?
    /// グラフが操作中でページ送りを止めてほしいあいだ真になります。バブルの拡大中だけ使います。
    @Binding var blocksPaging: Bool
    @Environment(ThemeStore.self) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var chartHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 340 : 156
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
            // 猫は**枠の縦中央**に置きます。下端で揃えると、猫の足元と金額の
            // ベースラインが並んでしまい、枠の中で沈んで見えます。
            HStack(alignment: .center, spacing: 12) {
            if let catMood {
                // **猫は合計の隣に座らせます。** 別の行に離すと、猫と数字が
                // それぞれ勝手に置かれているように見え、状況の要約として読まれません。
                CatCompanionView(mood: catMood)
                    .frame(width: 104, height: 104)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(periodLabel)
                    .font(.subheadline)
                    .foregroundStyle(BlackCatPalette.textMuted)

                Text(report.total, format: .currency(code: "JPY").precision(.fractionLength(0)))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(BlackCatPalette.text)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .contentTransition(.numericText(value: report.total))

                Text(entriesDescription)
                    .font(.caption)
                    .foregroundStyle(BlackCatPalette.textMuted)
            }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 14 : 12)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 11 : 8)
            .background(
                BlackCatPalette.surfaceElevated,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(BlackCatPalette.border, lineWidth: 0.8)
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
                    .foregroundStyle(BlackCatPalette.text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("この期間の利用コストはありません")
                } else {
                    chart
                }
            }
            .frame(maxWidth: .infinity, minHeight: chartHeight, maxHeight: chartHeight)
            .padding(dynamicTypeSize.isAccessibilitySize ? 12 : 12)
            .background(
                BlackCatPalette.surfaceElevated,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(BlackCatPalette.border, lineWidth: 0.8)
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
        case .bubble:
            BubbleChart(
                entries: report.entries,
                costTypeFilter: costTypeFilter,
                period: period,
                reduceMotion: reduceMotion,
                blocksPaging: $blocksPaging
            )
        case .column:
            ColumnChart(
                entries: report.entries,
                costTypeFilter: costTypeFilter,
                period: period,
                reduceMotion: reduceMotion
            )
        }
    }
}
