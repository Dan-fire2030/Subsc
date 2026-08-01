import Foundation

struct BubbleNode: Identifiable, Equatable {
    let id: String
    let center: CGPoint
    let radius: CGFloat

    static func == (lhs: BubbleNode, rhs: BubbleNode) -> Bool {
        lhs.id == rhs.id
            && lhs.center.x == rhs.center.x
            && lhs.center.y == rhs.center.y
            && lhs.radius == rhs.radius
    }
}

enum BubbleLayout {
    private enum Constants {
        static let radiusPaddingRatio: CGFloat = 0.02
        static let minimumPadding: CGFloat = 1
        /// 既存の円のまわりに試す角度の数です。多いほど詰まりますが計算量が増えます。
        static let candidateAngleCount = 72
        /// 浮動小数の誤差で「重なっている」と誤判定しないための許容差です。
        static let tolerance: CGFloat = 1e-9
        /// 描画時にわずかに縮める割合です。
        ///
        /// 配置は円が接するように詰めるため、そのまま描くと**漂うアニメーションで
        /// 隣同士が食い込みます**。一律に縮めれば面積比も非重複も保ったまま隙間ができます。
        static let renderRadiusRatio: CGFloat = 0.93
    }

    private struct IndexedEntry {
        let index: Int
        let entry: ReportChartItem
    }

    /// 金額比を保ったまま、すべての円を表示領域へ収められる配置を返します。
    ///
    /// 金額の大きい円から順に、既存の円へ接する位置のうち中心に最も近い場所へ置き、
    /// 最後に全体を一様に縮小します。一様な縮小なら円同士の非重複と面積比を同時に維持できます。
    static func layout(entries: [ReportChartItem], in size: CGSize) -> [BubbleNode] {
        guard size.width > 0, size.height > 0 else { return [] }

        let validEntries = entries.enumerated()
            .filter { $0.element.amount.isFinite && $0.element.amount > 0 }
            .map { IndexedEntry(index: $0.offset, entry: $0.element) }
            .sorted { first, second in
                if first.entry.amount == second.entry.amount {
                    return first.index < second.index
                }
                return first.entry.amount > second.entry.amount
            }

        guard !validEntries.isEmpty else { return [] }
        if validEntries.count == 1 {
            return [
                BubbleNode(
                    id: validEntries[0].entry.id,
                    center: CGPoint(x: size.width / 2, y: size.height / 2),
                    radius: min(size.width, size.height) / 2
                )
            ]
        }

        let unscaledRadii = validEntries.map { CGFloat(sqrt($0.entry.amount)) }
        guard let maximumRadius = unscaledRadii.first else { return [] }
        let padding = max(
            maximumRadius * Constants.radiusPaddingRatio,
            Constants.minimumPadding
        )
        var nodes: [BubbleNode] = []
        for (offset, indexedEntry) in validEntries.enumerated() {
            let radius = unscaledRadii[offset]
            let center: CGPoint
            if nodes.isEmpty {
                center = CGPoint(x: 0, y: 0)
            } else {
                center = packedCenter(
                    radius: radius,
                    padding: padding,
                    existingNodes: nodes,
                    aspect: size
                )
            }
            nodes.append(BubbleNode(id: indexedEntry.entry.id, center: center, radius: radius))
        }

        return fitted(nodes, in: size)
    }

    /// 既存の円に**接する位置**のうち、中心へ最も近いものを選びます。
    ///
    /// らせん上の等間隔な候補では、刻み幅を最大の円に合わせる必要があり、
    /// 小さい円ほど大きな隙間を空けて置かれてしまいます（実際、9件で領域の大半が空きました）。
    /// 接点を候補にすると円が寄り集まり、最後の一様縮小でも大きさを保てます。
    ///
    /// **「近さ」は表示領域の縦横比で正規化して測ります。** 素の距離で測るとクラスタが
    /// 円形になり、横長の領域では縦が先に埋まって左右に大きな余白が残ります。
    /// 正規化すると領域と相似な形に広がり、縦横のどちらもほぼ埋まります。
    private static func packedCenter(
        radius: CGFloat,
        padding: CGFloat,
        existingNodes: [BubbleNode],
        aspect: CGSize
    ) -> CGPoint {
        var bestCenter: CGPoint?
        var bestDistance = CGFloat.greatestFiniteMagnitude

        for anchor in existingNodes {
            let ringRadius = anchor.radius + radius + padding
            for step in 0..<Constants.candidateAngleCount {
                let angle = CGFloat(step) * 2 * .pi / CGFloat(Constants.candidateAngleCount)
                let candidate = CGPoint(
                    x: anchor.center.x + cos(angle) * ringRadius,
                    y: anchor.center.y + sin(angle) * ringRadius
                )

                let fits = existingNodes.allSatisfy { node in
                    hypot(candidate.x - node.center.x, candidate.y - node.center.y)
                        >= node.radius + radius + padding - Constants.tolerance
                }
                guard fits else { continue }

                let distance = hypot(
                    candidate.x / max(aspect.width, Constants.tolerance),
                    candidate.y / max(aspect.height, Constants.tolerance)
                )
                if distance < bestDistance - Constants.tolerance
                    || (abs(distance - bestDistance) <= Constants.tolerance
                        && isEarlier(candidate, than: bestCenter)) {
                    bestDistance = distance
                    bestCenter = candidate
                }
            }
        }

        if let bestCenter { return bestCenter }

        // 接点が1つも見つからないことは通常起きませんが、右端へ逃がして必ず配置を返します。
        let rightEdge = existingNodes.map { $0.center.x + $0.radius }.max() ?? 0
        return CGPoint(x: rightEdge + padding + radius, y: 0)
    }

    /// 同じ距離の候補が複数あるとき、実行ごとに結果が変わらないよう順序を決めます。
    private static func isEarlier(_ candidate: CGPoint, than current: CGPoint?) -> Bool {
        guard let current else { return true }
        if candidate.x != current.x { return candidate.x < current.x }
        return candidate.y < current.y
    }

    private static func fitted(_ nodes: [BubbleNode], in size: CGSize) -> [BubbleNode] {
        let minimumX = nodes.map { $0.center.x - $0.radius }.min() ?? 0
        let maximumX = nodes.map { $0.center.x + $0.radius }.max() ?? 0
        let minimumY = nodes.map { $0.center.y - $0.radius }.min() ?? 0
        let maximumY = nodes.map { $0.center.y + $0.radius }.max() ?? 0
        let contentWidth = maximumX - minimumX
        let contentHeight = maximumY - minimumY
        guard contentWidth > 0, contentHeight > 0 else { return [] }

        let scale = min(size.width / contentWidth, size.height / contentHeight)
        let contentCenter = CGPoint(
            x: (minimumX + maximumX) / 2,
            y: (minimumY + maximumY) / 2
        )
        let targetCenter = CGPoint(x: size.width / 2, y: size.height / 2)

        return nodes.map { node in
            BubbleNode(
                id: node.id,
                center: CGPoint(
                    x: (node.center.x - contentCenter.x) * scale + targetCenter.x,
                    y: (node.center.y - contentCenter.y) * scale + targetCenter.y
                ),
                radius: node.radius * scale * Constants.renderRadiusRatio
            )
        }
    }
}
