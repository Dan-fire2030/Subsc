import SwiftUI

enum BubbleChartTransform {
    static let minimumScale: CGFloat = 1
    static let maximumScale: CGFloat = 4

    static func clampedScale(_ proposedScale: CGFloat) -> CGFloat {
        min(maximumScale, max(minimumScale, proposedScale))
    }

    /// 等倍では必ず中央へ戻し、拡大中も全体が画面外へ流れ切らない範囲に留めます。
    static func clampedOffset(_ proposedOffset: CGSize, in size: CGSize, scale: CGFloat) -> CGSize {
        guard scale > minimumScale else { return .zero }
        let maximumX = max(0, size.width * (scale - minimumScale) / 2)
        let maximumY = max(0, size.height * (scale - minimumScale) / 2)
        return CGSize(
            width: min(maximumX, max(-maximumX, proposedOffset.width)),
            height: min(maximumY, max(-maximumY, proposedOffset.height))
        )
    }
}

/// 金額に比例する面積の円を、全件が収まる初期倍率から拡大して確認できます。
struct BubbleChart: View {
    let entries: [ReportEntry]
    let costTypeFilter: CostTypeFilter
    let period: ReportPeriod
    let reduceMotion: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsAllEntries = false
    @State private var scale = BubbleChartTransform.minimumScale
    @State private var offset = CGSize.zero
    @State private var magnificationStartScale: CGFloat?
    @State private var panStartOffset: CGSize?

    private enum Layout {
        static let inset: CGFloat = 12
        static let regularLabelRadius: CGFloat = 27
        static let accessibilityLabelRadius: CGFloat = 44
        static let resetAnimationDuration = 0.32
    }

    private var items: [ReportChartItem] {
        ReportChartPalette.items(from: entries, filter: costTypeFilter, period: period)
    }

    private var total: Double {
        items.reduce(0) { $0 + $1.amount }
    }

    private var isZoomed: Bool {
        scale > BubbleChartTransform.minimumScale
    }

    var body: some View {
        GeometryReader { proxy in
            let layoutSize = CGSize(
                width: max(0, proxy.size.width - Layout.inset * 2),
                height: max(0, proxy.size.height - Layout.inset * 2)
            )
            let nodes = BubbleLayout.layout(entries: items, in: layoutSize)

            bubbleCanvas(nodes: nodes, size: layoutSize)
                .scaleEffect(scale)
                .offset(offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
                .clipped()
                .simultaneousGesture(magnifyGesture(in: layoutSize))
                // 等倍ではDragGesture自体を外し、親のReportPagerへ横ドラッグを渡します。
                .gesture(isZoomed ? panGesture(in: layoutSize) : nil)
                // ダブルタップを先に宣言し、単タップの詳細表示と共存させます。
                .onTapGesture(count: 2) {
                    resetTransform()
                }
                .onTapGesture(count: 1) {
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

    private func bubbleCanvas(nodes: [BubbleNode], size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(nodes) { node in
                if let item = items.first(where: { $0.id == node.id }) {
                    BubbleNodeView(
                        item: item,
                        node: node,
                        total: total,
                        showsLabel: node.radius * scale >= minimumLabelRadius
                    )
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var minimumLabelRadius: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? Layout.accessibilityLabelRadius
            : Layout.regularLabelRadius
    }

    private func magnifyGesture(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let startingScale = magnificationStartScale ?? scale
                if magnificationStartScale == nil {
                    magnificationStartScale = startingScale
                }
                scale = BubbleChartTransform.clampedScale(
                    startingScale * value.magnification
                )
                offset = BubbleChartTransform.clampedOffset(offset, in: size, scale: scale)
                if scale == BubbleChartTransform.minimumScale {
                    offset = .zero
                    panStartOffset = nil
                }
            }
            .onEnded { _ in
                magnificationStartScale = nil
                offset = BubbleChartTransform.clampedOffset(offset, in: size, scale: scale)
            }
    }

    private func panGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let startingOffset = panStartOffset ?? offset
                if panStartOffset == nil {
                    panStartOffset = startingOffset
                }
                let proposedOffset = CGSize(
                    width: startingOffset.width + value.translation.width,
                    height: startingOffset.height + value.translation.height
                )
                offset = BubbleChartTransform.clampedOffset(proposedOffset, in: size, scale: scale)
            }
            .onEnded { _ in
                panStartOffset = nil
                offset = BubbleChartTransform.clampedOffset(offset, in: size, scale: scale)
            }
    }

    private func resetTransform() {
        let reset = {
            scale = BubbleChartTransform.minimumScale
            offset = .zero
            magnificationStartScale = nil
            panStartOffset = nil
        }
        if reduceMotion {
            reset()
        } else {
            withAnimation(.smooth(duration: Layout.resetAnimationDuration)) {
                reset()
            }
        }
    }
}

private struct BubbleNodeView: View {
    let item: ReportChartItem
    let node: BubbleNode
    let total: Double
    let showsLabel: Bool

    private enum Layout {
        static let highlightOpacity = 0.24
        static let highlightHeightRatio: CGFloat = 0.16
        static let highlightHorizontalInsetRatio: CGFloat = 0.42
        static let highlightTopInsetRatio: CGFloat = 0.13
        static let minimumHighlightHeight: CGFloat = 1
        static let labelSpacing: CGFloat = 1
        static let labelPadding: CGFloat = 5
        static let minimumLabelScale: CGFloat = 0.55
    }

    var body: some View {
        Circle()
            .fill(ReportChartPalette.color(for: item))
            .overlay(alignment: .top) {
                Circle()
                    .fill(.white.opacity(Layout.highlightOpacity))
                    .frame(
                        height: max(
                            Layout.minimumHighlightHeight,
                            node.radius * Layout.highlightHeightRatio
                        )
                    )
                    .padding(.horizontal, node.radius * Layout.highlightHorizontalInsetRatio)
                    .padding(.top, node.radius * Layout.highlightTopInsetRatio)
                    .accessibilityHidden(true)
            }
            .overlay {
                if showsLabel {
                    VStack(spacing: Layout.labelSpacing) {
                        Text(item.name)
                            .font(.caption2.weight(.semibold))
                        Text(item.amount, format: .currency(code: "JPY").precision(.fractionLength(0)))
                            .font(.caption2)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(Layout.minimumLabelScale)
                    .padding(Layout.labelPadding)
                    .accessibilityHidden(true)
                }
            }
            .frame(width: node.radius * 2, height: node.radius * 2)
            .position(node.center)
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
