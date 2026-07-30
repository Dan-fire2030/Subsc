import SwiftUI

/// ダッシュボード上部の利用コストレポートです。
/// 集計期間（月／年）とカーソル日をここで持ち、表示は `ReportPager` 以下へ委ねます。
struct ReportCard: View {
    let subscriptions: [Subscription]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var period: ReportPeriod = .month
    @State private var cursor = Date.now

    private var pages: [ReportPageData] {
        (-1...1).map { step in
            let pageCursor = shiftedCursor(by: step)
            return ReportPageData(
                step: step,
                report: report(at: pageCursor),
                periodLabel: periodLabel(for: pageCursor)
            )
        }
    }

    private var pageHeight: CGFloat {
        if dynamicTypeSize >= .accessibility3 {
            return 660
        }
        return dynamicTypeSize.isAccessibilitySize ? 520 : 264
    }

    var body: some View {
        let reportPages = pages
        let currentReport = reportPages.first { $0.step == 0 }?.report ??
            PaymentReport(total: 0, entries: [])

        VStack(alignment: .leading, spacing: 12) {
            Picker("集計期間", selection: $period) {
                ForEach(ReportPeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(3)
            .background(.black.opacity(0.12), in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(.white.opacity(0.3), lineWidth: 0.7)
            }
            .accessibilityLabel("レポート期間")

            ReportPager(
                pages: reportPages,
                pageHeight: pageHeight,
                periodUnit: periodUnit,
                reduceMotion: reduceMotion,
                isViewingCurrentPeriod: isViewingCurrentPeriod,
                accessibilityValue: accessibilityValue(for: currentReport),
                onShift: { step in
                    cursor = shiftedCursor(by: step)
                },
                onReturnToCurrentPeriod: {
                    cursor = .now
                }
            )
            .id(period)
        }
        .padding(14)
        .modifier(ReportCardSurfaceModifier())
        .onChange(of: period) {
            cursor = .now
        }
    }

    private var periodUnit: String {
        period == .month ? "月" : "年"
    }

    private var isViewingCurrentPeriod: Bool {
        ReportCalculator.isCurrentPeriod(cursor, period: period)
    }

    private func accessibilityValue(for report: PaymentReport) -> String {
        let total = report.total.formatted(
            .currency(code: "JPY").precision(.fractionLength(0))
        )
        return "\(periodLabel(for: cursor))、利用コスト\(total)、\(report.entries.count)件"
    }

    private func report(at date: Date) -> PaymentReport {
        ReportCalculator.report(
            subscriptions: subscriptions,
            period: period,
            cursor: date
        )
    }

    private func shiftedCursor(by value: Int) -> Date {
        ReportCalculator.shifted(cursor, period: period, by: value)
    }

    private func periodLabel(for date: Date) -> String {
        if period == .month {
            return date.formatted(.dateTime.year().month(.wide))
        }
        return date.formatted(.dateTime.year())
    }
}
