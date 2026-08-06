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
    /// 拡大しているあいだ真になります。**親のページ送りを止めてもらうため**に外へ出します。
    ///
    /// ジェスチャーの優先度指定では解決しません。ページ送りの横スクロールが内部で使う
    /// パン認識器はSwiftUIのジェスチャーとは別枠で、`highPriorityGesture` にしても
    /// タッチを先に掴みます。**競合を消すには、そもそもスクロールを止めるしかありません。**
    @Binding var blocksPaging: Bool

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
        /// 吹き出しを自動で消すまでの秒数です。出しっぱなしにすると次のタップまで残ります。
        static let calloutLifetime: Duration = .seconds(2.6)
    }

    /// タップで名前と金額を出している円です。同時に1つだけ出します。
    @State private var calloutNodeID: String?
    @State private var calloutDismissTask: Task<Void, Never>?

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
                // ズーム中は親のスクロールが止まっているので、こちらだけがドラッグを受け取ります。
                .gesture(isZoomed ? panGesture(in: layoutSize) : nil)
                // ダブルタップを先に宣言し、単タップの詳細表示と共存させます。
                .onTapGesture(count: 2) {
                    resetTransform()
                }
                // ラベルが入らない小さい円は、タップでその場に名前と金額を出します。
                // 大きい円と背景は従来どおり内訳シートを開きます。
                .onTapGesture(count: 1) { location in
                    handleTap(at: location, nodes: nodes, size: layoutSize, in: proxy.size)
                }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.38), value: items)
        // 拡大の開始・終了に合わせて、親のページ送りを止める・戻すを切り替えます。
        //
        // **`initial:` は付けません。** ページャは前後のページも作るため、
        // 表示のたびに false を書くと、拡大中のページの指定を隣のページが打ち消します。
        .onChange(of: isZoomed) { _, zoomed in
            blocksPaging = zoomed
        }
        .onDisappear {
            // 画面から外れたまま止めっぱなしにすると、ページ送りが二度と効かなくなります。
            // 拡大中はスクロールが止まっていて隣のページは作り直されないので、
            // ここで隣のページが誤って解除してしまうことはありません。
            blocksPaging = false
        }
        .sheet(isPresented: $showsAllEntries) {
            ReportBreakdownSheet(entries: entries)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .adaptiveSheetBackground()
        }
    }

    private func bubbleCanvas(nodes: [BubbleNode], size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            // **`GlassEffectContainer` では包みません。** ガラスを1枚へまとめる際、
            // 中に置いた非ガラスの中身（円のラベルと上部の光沢）がガラスの下へ潜り、
            // 完全に見えなくなります。取り込みをまとめる負荷より、費目名と金額が
            // 出ないことのほうが致命的なので、円ごとに `glassEffect` を当てます。
            ZStack(alignment: .topLeading) {
                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    if let item = items.first(where: { $0.id == node.id }) {
                        BubbleNodeView(
                            item: item,
                            node: node,
                            total: total,
                            showsLabel: node.radius * scale >= minimumLabelRadius,
                            driftIndex: index,
                            reduceMotion: reduceMotion
                        )
                    }
                }
            }
            .frame(width: size.width, height: size.height)

            if let calloutNodeID,
               let node = nodes.first(where: { $0.id == calloutNodeID }),
               let item = items.first(where: { $0.id == calloutNodeID }) {
                BubbleCallout(item: item, total: total)
                    .position(calloutPosition(for: node, in: size))
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(reduceMotion ? nil : .spring(duration: 0.28, bounce: 0.35), value: calloutNodeID)
    }

    /// 吹き出しは円の直上に置きますが、上端から出てしまうときは円の下へ回り込ませます。
    private func calloutPosition(for node: BubbleNode, in size: CGSize) -> CGPoint {
        let gap = node.radius + BubbleCallout.estimatedHeight / 2 + 6
        let above = node.center.y - gap
        let y = above - BubbleCallout.estimatedHeight / 2 < 0 ? node.center.y + gap : above
        let halfWidth = BubbleCallout.estimatedWidth / 2
        let x = min(max(node.center.x, halfWidth), max(halfWidth, size.width - halfWidth))
        return CGPoint(x: x, y: y)
    }

    /// タップ位置にラベルなしの円があれば吹き出しを出し、無ければ内訳シートを開きます。
    private func handleTap(
        at location: CGPoint,
        nodes: [BubbleNode],
        size: CGSize,
        in containerSize: CGSize
    ) {
        // 描画は inset だけ内側にあり、さらに拡大・移動されているため、
        // タップ座標を配置計算の座標系へ戻してから当たり判定します。
        let centered = CGPoint(
            x: location.x - containerSize.width / 2 - offset.width,
            y: location.y - containerSize.height / 2 - offset.height
        )
        let inLayout = CGPoint(
            x: centered.x / scale + size.width / 2,
            y: centered.y / scale + size.height / 2
        )

        let hit = nodes
            .filter { node in
                node.radius * scale < minimumLabelRadius
                    && hypot(inLayout.x - node.center.x, inLayout.y - node.center.y) <= node.radius
            }
            // 円が重なって見えるほど近い場合は、小さいほうを優先して拾えるようにします。
            .min { $0.radius < $1.radius }

        guard let hit else {
            calloutDismissTask?.cancel()
            calloutNodeID = nil
            showsAllEntries = true
            return
        }

        calloutDismissTask?.cancel()
        calloutNodeID = hit.id
        calloutDismissTask = Task {
            try? await Task.sleep(for: Layout.calloutLifetime)
            guard !Task.isCancelled else { return }
            calloutNodeID = nil
        }
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

    /// ズーム中のパンです。**指を置いた瞬間から追従させたいので `minimumDistance` は0**にします。
    /// 1以上にすると動き出しがわずかに遅れ、掴んでいる感覚が薄れます。
    private func panGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
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
    /// 位相と周期をずらすための通し番号です。全部が同じ動きだと機械的に見えます。
    let driftIndex: Int
    let reduceMotion: Bool

    @State private var isDriftingVertically = false
    @State private var isDriftingHorizontally = false
    @State private var hasAppeared = false

    private enum Layout {
        static let labelSpacing: CGFloat = 1
        static let labelPadding: CGFloat = 5
        static let minimumLabelScale: CGFloat = 0.55
        /// 漂う幅は半径に対する比で決めます。円同士の間隔より小さく保ち、重なって見せません。
        static let driftRatio: CGFloat = 0.09
        static let maximumDrift: CGFloat = 4.5
        /// 左右は上下より控えめにします。同じ幅で動かすと、斜めに滑って見えます。
        static let horizontalDriftScale: CGFloat = 0.62
        static let baseDriftDuration = 2.9
        static let driftDurationStep = 0.23
        /// **上下と左右で周期をずらします。** 同じ周期だと往復が直線になり、
        /// 8の字にならず「斜めに行ったり来たり」に見えます。
        static let horizontalDurationRatio = 1.45
    }

    /// 円ごとにずらした振れ幅です。
    private var driftMagnitude: CGFloat {
        min(node.radius * Layout.driftRatio, Layout.maximumDrift)
    }

    private var verticalDrift: CGFloat {
        guard isDriftingVertically else { return 0 }
        // 交互に上下へ動かし、隣り合う円が同じ向きに揃わないようにします。
        return driftIndex.isMultiple(of: 2) ? -driftMagnitude : driftMagnitude
    }

    private var horizontalDrift: CGFloat {
        guard isDriftingHorizontally else { return 0 }
        let magnitude = driftMagnitude * Layout.horizontalDriftScale
        // 上下とは別の周期で分けます。3つおきにすると、上下の2つおきと噛み合いません。
        return driftIndex % 3 == 0 ? -magnitude : magnitude
    }

    private var driftDuration: Double {
        Layout.baseDriftDuration + Double(driftIndex % 5) * Layout.driftDurationStep
    }

    private var horizontalDriftDuration: Double {
        driftDuration * Layout.horizontalDurationRatio
    }

    var body: some View {
        ReportChartShape(shape: Circle(), color: ReportChartPalette.color(for: item))
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
            // **落ち影は持ちません（2026-08-06）。** 円の色を薄く敷いた影は、
            // 淡いカテゴリ色ほど円の外側へ滲んで「発光している」ように見え、
            // 隣り合う円の境目を曖昧にしていました。円同士は余白で分けます。
            .offset(x: horizontalDrift, y: verticalDrift)
            .scaleEffect(hasAppeared ? 1 : 0.55)
            .opacity(hasAppeared ? 1 : 0)
            .position(node.center)
            .onAppear { startAnimations() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.isEstimated ? "\(item.name)、見込み" : item.name)
            .accessibilityValue(accessibilityValue)
    }

    /// 登場のバネと、その後の漂う往復を始めます。
    /// `reduceMotion` のときはどちらも動かさず、最終状態で置きます。
    private func startAnimations() {
        guard !reduceMotion else {
            hasAppeared = true
            return
        }
        withAnimation(.spring(duration: 0.45, bounce: 0.45).delay(Double(driftIndex) * 0.035)) {
            hasAppeared = true
        }
        withAnimation(
            .easeInOut(duration: driftDuration)
                .repeatForever(autoreverses: true)
                .delay(Double(driftIndex % 4) * 0.18)
        ) {
            isDriftingVertically = true
        }
        // **上下とは別に開始します。** 同時に始めると位相が揃い、往復が直線になります。
        withAnimation(
            .easeInOut(duration: horizontalDriftDuration)
                .repeatForever(autoreverses: true)
                .delay(Double(driftIndex % 3) * 0.29)
        ) {
            isDriftingHorizontally = true
        }
    }

    private var accessibilityValue: String {
        let amount = item.amount.formatted(.currency(code: "JPY").precision(.fractionLength(0)))
        let percentage = ReportChartPalette.fraction(for: item, total: total)
            .formatted(.percent.precision(.fractionLength(0)))
        return "\(amount)、\(percentage)"
    }
}

/// 小さすぎてラベルが入らない円のために、タップでその場に名前と金額を出します。
private struct BubbleCallout: View {
    let item: ReportChartItem
    let total: Double

    /// 位置決めに使う概算です。実測を待たずに置き場所を決めたいので定数にしています。
    static let estimatedWidth: CGFloat = 120
    static let estimatedHeight: CGFloat = 34

    var body: some View {
        VStack(spacing: 1) {
            Text(item.isEstimated ? "\(item.name)（見込み）" : item.name)
                .font(.caption2.weight(.semibold))
            Text(item.amount, format: .currency(code: "JPY").precision(.fractionLength(0)))
                .font(.caption2)
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .lineLimit(1)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        // **下地の黒は薄くしません。** 文字が白なので、明るい面に置き換えると
        // 背後の円の色によっては読めなくなります。
        //
        // **縁は持ちません（2026-08-06）。** 円がマットになったので、縁だけが光ると
        // ラベルの方が円より手前の部品に見えます。読みやすさは下地の黒で足りています。
        .background(.black.opacity(0.5), in: Capsule(style: .continuous))
        .accessibilityHidden(true)
    }
}
