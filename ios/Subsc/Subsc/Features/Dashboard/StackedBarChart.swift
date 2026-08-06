import SwiftUI

/// 金額の構成比を、最小幅を保証した1本の帯として見せます。
struct StackedBarChart: View {
    let entries: [ReportEntry]
    let costTypeFilter: CostTypeFilter
    let period: ReportPeriod
    let reduceMotion: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsAllEntries = false

    private enum Layout {
        static let segmentSpacing: CGFloat = 2
        static let segmentHeight: CGFloat = 34
        static let minimumSegmentWidth: CGFloat = 6
        static let contentSpacing: CGFloat = 10
        static let legendColumnWidth: CGFloat = 112
        /// 種別集計なら最大4件なので全件入ります。絞り込み中は費目ごとになるため
        /// 件数が増えますが、130ptの領域に収まる行数がここまでです。
        static let maximumRegularLegendCount = 6
        static let maximumAccessibilityLegendCount = 3
    }

    private var items: [ReportChartItem] {
        ReportChartPalette.items(from: entries, filter: costTypeFilter, period: period)
    }

    private var total: Double {
        items.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        GeometryReader { proxy in
            let legendLimit = legendLimit(for: proxy.size.width)
            let visibleItems = Array(items.prefix(legendLimit))
            let hiddenCount = max(0, items.count - visibleItems.count)

            ZStack {
                VStack(alignment: .leading, spacing: Layout.contentSpacing) {
                    stackedBand(width: proxy.size.width)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: Layout.legendColumnWidth), alignment: .leading)],
                        alignment: .leading,
                        spacing: 6
                    ) {
                        ForEach(visibleItems) { item in
                            StackedBarLegendItem(item: item, total: total)
                        }
                        if hiddenCount > 0 {
                            Text("ほか\(hiddenCount)件")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(BlackCatPalette.textMuted)
                                .accessibilityLabel("ほか\(hiddenCount)件。詳細で確認できます")
                        }
                    }

                    Spacer(minLength: 0)
                }

                chartDetailButton
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

    private func stackedBand(width: CGFloat) -> some View {
        let spacing = min(
            Layout.segmentSpacing,
            width / CGFloat(max(1, items.count * 3))
        )
        let availableWidth = max(
            0,
            width - spacing * CGFloat(max(0, items.count - 1))
        )
        let lengths = ReportChartPalette.lengths(
            for: items,
            availableLength: availableWidth,
            minimumLength: Layout.minimumSegmentWidth
        )

        return HStack(spacing: spacing) {
            ForEach(Array(zip(items, lengths)), id: \.0.id) { item, length in
                ReportChartGlassShape(
                    shape: RoundedRectangle(cornerRadius: 8, style: .continuous),
                    color: ReportChartPalette.color(for: item),
                    glossHeight: 2.5,
                    // 帯は横に細長いので、光沢を比で入れると端まで届いて線に見えます。
                    glossInsetRatio: 0.08
                )
                    .frame(width: length, height: Layout.segmentHeight)
                    .accessibilityElement()
                    .accessibilityLabel(accessibilityLabel(for: item))
                    .accessibilityValue(accessibilityValue(for: item))
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

    /// 凡例に出す件数です。
    ///
    /// **横に何列入るかで打ち切らないこと。** グリッドは折り返せるので、
    /// 幅から列数を求めて上限にすると、縦に余裕があるのに隠れてしまいます
    /// （種別は最大4つしかないのに2つしか出ない状態になっていました）。
    /// 制限は縦に入る行数だけを根拠にします。
    private func legendLimit(for width: CGFloat) -> Int {
        dynamicTypeSize.isAccessibilitySize
            ? Layout.maximumAccessibilityLegendCount
            : Layout.maximumRegularLegendCount
    }

    private func accessibilityLabel(for item: ReportChartItem) -> String {
        item.isEstimated ? "\(item.name)、見込み" : item.name
    }

    private func accessibilityValue(for item: ReportChartItem) -> String {
        let amount = item.amount.formatted(.currency(code: "JPY").precision(.fractionLength(0)))
        let percentage = ReportChartPalette.fraction(for: item, total: total)
            .formatted(.percent.precision(.fractionLength(0)))
        return "\(amount)、\(percentage)"
    }
}

private struct StackedBarLegendItem: View {
    let item: ReportChartItem
    let total: Double

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(ReportChartPalette.color(for: item))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Text(item.name)
                .lineLimit(1)

            Text(ReportChartPalette.fraction(for: item, total: total), format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(BlackCatPalette.text)
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
