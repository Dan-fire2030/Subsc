import SwiftUI

enum ColumnChartGeometry {
    static func contentWidth(
        itemCount: Int,
        barWidth: CGFloat,
        spacing: CGFloat,
        horizontalPadding: CGFloat
    ) -> CGFloat {
        guard itemCount > 0 else { return 0 }
        return CGFloat(itemCount) * barWidth
            + CGFloat(max(0, itemCount - 1)) * spacing
            + horizontalPadding * 2
    }

    static func barHeight(
        amount: Double,
        maximumAmount: Double,
        availableHeight: CGFloat,
        minimumHeight: CGFloat
    ) -> CGFloat {
        guard availableHeight > 0 else { return 0 }
        let minimum = min(max(0, minimumHeight), availableHeight)
        guard maximumAmount.isFinite, maximumAmount > 0, amount.isFinite else {
            return minimum
        }
        let fraction = min(1, max(0, amount / maximumAmount))
        return minimum + (availableHeight - minimum) * CGFloat(fraction)
    }
}

/// 金額順の縦バーを横へ並べ、件数が多いときは内側だけを慣性スクロールできます。
struct ColumnChart: View {
    let entries: [ReportEntry]
    let costTypeFilter: CostTypeFilter
    let period: ReportPeriod
    let reduceMotion: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsAllEntries = false

    private enum Layout {
        static let regularBarWidth: CGFloat = 56
        static let accessibilityBarWidth: CGFloat = 92
        static let regularSpacing: CGFloat = 12
        static let accessibilitySpacing: CGFloat = 18
        static let horizontalPadding: CGFloat = 10
        static let verticalPadding: CGFloat = 7
        static let regularReservedTextHeight: CGFloat = 40
        static let accessibilityReservedTextHeight: CGFloat = 88
        static let minimumBarHeight: CGFloat = 8
        static let cornerRadius: CGFloat = 10
        static let edgeFadeWidth: CGFloat = 0.07
    }

    private var items: [ReportChartItem] {
        ReportChartPalette.items(from: entries, filter: costTypeFilter, period: period)
    }

    private var total: Double {
        items.reduce(0) { $0 + $1.amount }
    }

    private var maximumAmount: Double {
        items.map(\.amount).max() ?? 0
    }

    private var barWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? Layout.accessibilityBarWidth
            : Layout.regularBarWidth
    }

    private var spacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? Layout.accessibilitySpacing
            : Layout.regularSpacing
    }

    private var reservedTextHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? Layout.accessibilityReservedTextHeight
            : Layout.regularReservedTextHeight
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = ColumnChartGeometry.contentWidth(
                itemCount: items.count,
                barWidth: barWidth,
                spacing: spacing,
                horizontalPadding: Layout.horizontalPadding
            )
            let canScroll = contentWidth > proxy.size.width
            let availableBarHeight = max(
                0,
                proxy.size.height - reservedTextHeight - Layout.verticalPadding * 2
            )

            ScrollView(.horizontal) {
                LazyHStack(alignment: .bottom, spacing: spacing) {
                    ForEach(items) { item in
                        ColumnItemView(
                            item: item,
                            total: total,
                            height: ColumnChartGeometry.barHeight(
                                amount: item.amount,
                                maximumAmount: maximumAmount,
                                availableHeight: availableBarHeight,
                                minimumHeight: Layout.minimumBarHeight
                            ),
                            width: barWidth
                        )
                    }
                }
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.vertical, Layout.verticalPadding)
                .frame(minWidth: proxy.size.width, minHeight: proxy.size.height, alignment: .bottomLeading)
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(!canScroll)
            // 下地です。**他のグラフと同じ `chartTrack` を敷きます。**
            // 以前は黒を重ね、スクロールできるときだけ濃くしていましたが、白磁の地（ライト）では
            // どちらの濃さも地に埋もれて差が読めませんでした。**スクロールできることは
            // 端のフェード（下の `mask`）が示す**ので、下地は濃さを変えません。
            .background(BlackCatPalette.chartTrack, in: .rect(cornerRadius: Layout.cornerRadius))
            .mask {
                if canScroll {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: Layout.edgeFadeWidth),
                            .init(color: .black, location: 1 - Layout.edgeFadeWidth),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                } else {
                    Rectangle()
                }
            }
            .contentShape(.rect)
            .onTapGesture {
                showsAllEntries = true
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.38), value: items)
        .sheet(isPresented: $showsAllEntries) {
            ReportBreakdownSheet(entries: entries)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .adaptiveSheetBackground()
        }
    }
}

private struct ColumnItemView: View {
    let item: ReportChartItem
    let total: Double
    let height: CGFloat
    let width: CGFloat

    private enum Layout {
        static let contentSpacing: CGFloat = 3
        static let barCornerRadius: CGFloat = 8
        static let minimumAmountScale: CGFloat = 0.55
    }

    var body: some View {
        VStack(spacing: Layout.contentSpacing) {
            // **文字は棒の外に置くので、地の色に応じた文字色を使います。**
            // 白で固定すると、白磁の地（ライト）では金額も費目名も読めなくなります。
            Text(item.amount, format: .currency(code: "JPY").precision(.fractionLength(0)))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BlackCatPalette.text)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(Layout.minimumAmountScale)

            // **単色のフラット塗りです（2026-08-06）。** 上端の光沢は色の上に白を乗せる
            // 処理で、淡いカテゴリ色ほど白飛びして隣の棒と見分けづらくなっていました。
            RoundedRectangle(cornerRadius: Layout.barCornerRadius, style: .continuous)
                .fill(ReportChartPalette.color(for: item))
                .frame(height: height)

            Text(item.name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BlackCatPalette.textMuted)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(width: width)
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
