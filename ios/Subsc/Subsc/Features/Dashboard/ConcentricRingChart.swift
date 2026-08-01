import SwiftUI

/// 大きい金額から外側へ並べ、各リングの長さで全体に占める割合を見せます。
struct ConcentricRingChart: View {
    let entries: [ReportEntry]
    let costTypeFilter: CostTypeFilter
    let period: ReportPeriod
    let reduceMotion: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsAllEntries = false

    private enum Layout {
        static let ringWidth: CGFloat = 9
        static let ringSpacing: CGFloat = 5
        static let regularDiameter: CGFloat = 104
        static let accessibilityDiameter: CGFloat = 180
        static let minimumFraction = 0.025
        static let maximumRingCount = 4
        static let chartSpacing: CGFloat = 12
    }

    private var items: [ReportChartItem] {
        ReportChartPalette.items(from: entries, filter: costTypeFilter, period: period)
    }

    private var visibleItems: [ReportChartItem] {
        Array(items.prefix(Layout.maximumRingCount))
    }

    private var total: Double {
        items.reduce(0) { $0 + $1.amount }
    }

    private var diameter: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? Layout.accessibilityDiameter
            : Layout.regularDiameter
    }

    var body: some View {
        ZStack {
            chartContent
            chartDetailButton
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.38), value: items)
        .sheet(isPresented: $showsAllEntries) {
            ReportBreakdownSheet(entries: entries)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .adaptiveSheetBackground()
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: Layout.chartSpacing) {
                rings
                legend
            }
        } else {
            HStack(spacing: Layout.chartSpacing) {
                rings
                legend
            }
        }
    }

    private var rings: some View {
        ZStack {
            ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                let inset = CGFloat(index) * (Layout.ringWidth + Layout.ringSpacing)
                let fraction = max(
                    Layout.minimumFraction,
                    ReportChartPalette.fraction(for: item, total: total)
                )

                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: Layout.ringWidth)
                    .padding(inset)

                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        ReportChartPalette.color(for: item),
                        style: StrokeStyle(lineWidth: Layout.ringWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(inset)
                    .accessibilityElement()
                    .accessibilityLabel(item.isEstimated ? "\(item.name)、見込み" : item.name)
                    .accessibilityValue(accessibilityValue(for: item))
            }

            VStack(spacing: 1) {
                Text("合計")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                Text(total, format: .currency(code: "JPY").precision(.fractionLength(0)))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
            }
            .padding(32)
            .accessibilityElement(children: .combine)
        }
        .frame(width: diameter, height: diameter)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 8 : 5) {
            ForEach(visibleItems) { item in
                ConcentricRingLegendItem(item: item, total: total)
            }

            if items.count > visibleItems.count {
                Text("ほか\(items.count - visibleItems.count)件")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .accessibilityLabel("ほか\(items.count - visibleItems.count)件。詳細で確認できます")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chartDetailButton: some View {
        Button {
            showsAllEntries = true
        } label: {
            Color.clear
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("費目別料金の詳細")
        .accessibilityHint("ダブルタップしてすべての費目を確認します")
    }

    private func accessibilityValue(for item: ReportChartItem) -> String {
        let amount = item.amount.formatted(.currency(code: "JPY").precision(.fractionLength(0)))
        let percentage = ReportChartPalette.fraction(for: item, total: total)
            .formatted(.percent.precision(.fractionLength(0)))
        return "\(amount)、\(percentage)"
    }
}

private struct ConcentricRingLegendItem: View {
    let item: ReportChartItem
    let total: Double

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ReportChartPalette.color(for: item))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                Text(item.amount, format: .currency(code: "JPY").precision(.fractionLength(0)))
                    .font(.caption2)
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.isEstimated ? "\(item.name)、見込み" : item.name)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        let amount = item.amount.formatted(.currency(code: "JPY").precision(.fractionLength(0)))
        let percentage = ReportChartPalette.fraction(for: item, total: total)
            .formatted(.percent.precision(.fractionLength(0)))
        return "\(amount)、\(percentage)"
    }
}
