import SwiftUI

/// ページャの1ページ、つまり1期間ぶんの表示です。
/// 合計額のヘッダーとチャート枠を持ち、登録がない期間は代わりに案内を出します。
struct ReportPage: View {
    let report: PaymentReport
    let periodLabel: String
    let reduceMotion: Bool
    let costTypeFilter: CostTypeFilter
    let period: ReportPeriod
    /// 相棒の黒猫です。**どのページにも座ります。**
    /// 前後のページには平常の姿が渡ります（状態は今月の支出から決まるため）。
    let catMood: CatMood
    /// 今の期間のページかどうかです。
    ///
    /// **猫の有無で代用しません。** 猫は全ページに座るようになったので、
    /// 「今の期間だけに出すもの」は自前の印で判断する必要があります。
    let isCurrentPeriod: Bool
    /// グラフが操作中でページ送りを止めてほしいあいだ真になります。バブルの拡大中だけ使います。
    @Binding var blocksPaging: Bool
    /// 「今」の基準です。**進み具合と日付で同じ瞬間を使う**ために1箇所で持ちます。
    var now: Date = .now
    var calendar: Calendar = .current
    @Environment(ThemeStore.self) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var chartHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 340 : 156
    }

    /// 月のどこにいるかです。**今の月のページにだけ**出します。
    ///
    /// 合計だけでは多いか少ないかを判断できません。月初の ¥88,586 と月末の ¥88,586 は
    /// 意味が違うので、**どこまで進んだ月の合計なのか**を添えます。
    /// 年間表示と、過ぎた月・これからの月では意味を成さないので出しません。
    private var monthProgress: (fraction: Double, remainingDays: Int)? {
        guard isCurrentPeriod, period == .month else { return nil }
        return MonthProgress.current(now: now, calendar: calendar)
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
            VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
            // **猫は合計の隣に座らせます。** 別の行に離すと、猫と数字が
            // それぞれ勝手に置かれているように見え、状況の要約として読まれません。
            CatCompanionView(mood: catMood)
                .frame(width: 104, height: 104)
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

            if let monthProgress {
                MonthProgressLine(
                    progress: monthProgress.fraction,
                    remainingDays: monthProgress.remainingDays,
                    date: now
                )
            }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // **中身の縁と面の縁を離します。** 以前は上下8ptしかなく、猫と金額が
            // 枠にぶつかって見えていました。角丸18ptの内側で余白が足りないと、
            // 角の丸みが中身に食い込み、枠が切れているようにも見えます。
            .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 18 : 16)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 16 : 14)
            .background { ReportInnerSurface(cornerRadius: 18) }

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
            .padding(14)
            .background { ReportInnerSurface(cornerRadius: 20) }
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
