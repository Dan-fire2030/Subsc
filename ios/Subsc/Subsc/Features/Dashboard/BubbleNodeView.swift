import SwiftUI

/// バブルの円ひとつと、円に収まらないラベルのためのふきだしです。
///
/// **`BubbleChart.swift` から切り出しました（2026-08-08）。** 1ファイル423行あり、
/// AGENTS.mdの400行目安を超えていました。ジェスチャーの扱いは動かしていません。
/// ファイルをまたぐため `private` は外しています。
struct BubbleNodeView: View {
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
struct BubbleCallout: View {
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

