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
        /// 余白を詰める繰り返しの上限です。収束が速いので、これだけあれば余白は1%を切ります。
        static let spreadPassCount = 6
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

    /// 円をすべて含む外接矩形です。半径ぶんまで含めて測ります。
    private struct Bounds {
        let minimumX: CGFloat
        let maximumX: CGFloat
        let minimumY: CGFloat
        let maximumY: CGFloat

        var width: CGFloat { maximumX - minimumX }
        var height: CGFloat { maximumY - minimumY }
        var center: CGPoint {
            CGPoint(x: (minimumX + maximumX) / 2, y: (minimumY + maximumY) / 2)
        }
    }

    private static func bounds(of nodes: [BubbleNode]) -> Bounds? {
        guard
            let minimumX = nodes.map({ $0.center.x - $0.radius }).min(),
            let maximumX = nodes.map({ $0.center.x + $0.radius }).max(),
            let minimumY = nodes.map({ $0.center.y - $0.radius }).min(),
            let maximumY = nodes.map({ $0.center.y + $0.radius }).max()
        else { return nil }
        return Bounds(
            minimumX: minimumX,
            maximumX: maximumX,
            minimumY: minimumY,
            maximumY: maximumY
        )
    }

    private static func fitted(_ nodes: [BubbleNode], in size: CGSize) -> [BubbleNode] {
        guard let box = bounds(of: nodes), box.width > 0, box.height > 0 else { return [] }

        let scale = min(size.width / box.width, size.height / box.height)
        let scaled = nodes.map { node in
            BubbleNode(
                id: node.id,
                center: CGPoint(
                    x: (node.center.x - box.center.x) * scale,
                    y: (node.center.y - box.center.y) * scale
                ),
                radius: node.radius * scale * Constants.renderRadiusRatio
            )
        }

        return centered(spread(scaled, in: size), in: size)
    }

    /// 余白が無くなるまで `spread` を繰り返します。
    ///
    /// 1回では埋まりません。**半径は広がらないので、外接矩形は掛けた倍率どおりには伸びない**
    /// ためです（実測で残り約5%）。残りに対して同じ操作を繰り返せば急速に収束します。
    /// 毎回1以上の倍率しか掛けないので、繰り返しても円が近づくことはありません。
    private static func spread(_ nodes: [BubbleNode], in size: CGSize) -> [BubbleNode] {
        var spread = nodes
        for _ in 0..<Constants.spreadPassCount {
            let next = spreadOnce(spread, in: size)
            if next == spread { break }
            spread = next
        }
        return spread
    }

    /// 等方縮小のあとに残る余白を、**中心の間隔だけを広げて**埋めます。
    ///
    /// 等方縮小は縦横のうち厳しいほうの軸に合わせるため、もう一方には必ず余白が残ります
    /// （実機の枠では横に約2割空いていました）。半径を変えずに中心どうしを離せば、
    /// **面積比はそのまま、円同士の距離は縮まないので重なりも増えません。**
    ///
    /// 半径は広がらないぶん外接矩形は倍率どおりには伸びず、領域をわずかに残して収まります。
    /// **はみ出す側へは決して動かないので、これは安全側のズレです。**
    private static func spreadOnce(_ nodes: [BubbleNode], in size: CGSize) -> [BubbleNode] {
        guard nodes.count > 1, let box = bounds(of: nodes), box.width > 0, box.height > 0 else {
            return nodes
        }

        let horizontal = max(1, size.width / box.width)
        let vertical = max(1, size.height / box.height)
        guard horizontal > 1 || vertical > 1 else { return nodes }

        return nodes.map { node in
            BubbleNode(
                id: node.id,
                center: CGPoint(
                    x: box.center.x + (node.center.x - box.center.x) * horizontal,
                    y: box.center.y + (node.center.y - box.center.y) * vertical
                ),
                radius: node.radius
            )
        }
    }

    private static func centered(_ nodes: [BubbleNode], in size: CGSize) -> [BubbleNode] {
        guard let box = bounds(of: nodes) else { return nodes }

        let horizontalShift = size.width / 2 - box.center.x
        let verticalShift = size.height / 2 - box.center.y

        return nodes.map { node in
            BubbleNode(
                id: node.id,
                center: CGPoint(
                    x: node.center.x + horizontalShift,
                    y: node.center.y + verticalShift
                ),
                radius: node.radius
            )
        }
    }
}
