import SwiftUI

/// ダッシュボード上部の利用コストレポートです。
/// 集計期間（月／年）とカーソル日をここで持ち、表示は `ReportPager` 以下へ委ねます。
struct ReportCard: View {
    let subscriptions: [Subscription]
    /// 返済額もレポートに含めます。**種別の絞り込みは呼び出し側で適用済み**です。
    let loans: [Loan]
    /// グラフの集計単位と色を絞り込み状態に合わせるため、文字列ではなく条件自体を渡します。
    let costTypeFilter: CostTypeFilter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var period: ReportPeriod = .month
    /// ページャの `step == 0` が指す日です。
    ///
    /// スクロール位置は `ReportPager` の中だけで持ちます。ここで持つと、慣性で流れている最中に
    /// カードごと作り直されてスクロールが途切れるためです。
    /// このカードは基準日だけを提供し、どのページを見ているかには関与しません。
    @State private var anchor = Date.now

    private func page(at step: Int) -> ReportPageData {
        let pageCursor = shiftedAnchor(by: step)
        return ReportPageData(
            step: step,
            report: report(at: pageCursor),
            periodLabel: periodLabel(for: pageCursor)
        )
    }

    private var pageHeight: CGFloat {
        if dynamicTypeSize >= .accessibility3 {
            return 660
        }
        return dynamicTypeSize.isAccessibilitySize ? 520 : 292
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("集計期間", selection: $period) {
                ForEach(ReportPeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(3)
            .background(BlackCatPalette.surfaceElevated, in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(BlackCatPalette.border, lineWidth: 0.7)
            }
            .accessibilityLabel("レポート期間")

            if costTypeFilter.isNarrowed {
                let costTypeTitle = costTypeFilter.title
                Label(costTypeTitle, systemImage: "line.3.horizontal.decrease")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(BlackCatPalette.textMuted)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(BlackCatPalette.surfaceElevated, in: Capsule())
                    .accessibilityLabel("\(costTypeTitle)だけを集計しています")
            }

            ReportPager(
                makePage: page(at:),
                pageHeight: pageHeight,
                periodUnit: periodUnit,
                reduceMotion: reduceMotion,
                costTypeFilter: costTypeFilter,
                period: period,
                accessibilityValue: accessibilityValue(for:),
                onReturnToCurrentPeriod: {
                    // 日付をまたいで基準が古くなっている場合に備え、戻るときに取り直します。
                    anchor = .now
                }
            )
            .id(period)
        }
        .padding(14)
        .modifier(ReportCardSurfaceModifier())
        .onChange(of: period) {
            anchor = .now
        }
    }

    private var periodUnit: String {
        period == .month ? "月" : "年"
    }

    private func accessibilityValue(for page: ReportPageData) -> String {
        let total = page.report.total.formatted(
            .currency(code: "JPY").precision(.fractionLength(0))
        )
        return "\(page.periodLabel)、利用コスト\(total)、\(page.report.entries.count)件"
    }

    private func report(at date: Date) -> PaymentReport {
        ReportCalculator.report(
            subscriptions: subscriptions,
            loans: loans,
            period: period,
            cursor: date
        )
    }

    private func shiftedAnchor(by value: Int) -> Date {
        ReportCalculator.shifted(anchor, period: period, by: value)
    }

    private func periodLabel(for date: Date) -> String {
        if period == .month {
            return date.formatted(.dateTime.year().month(.wide))
        }
        return date.formatted(.dateTime.year())
    }
}
