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
        static let goldenAngle = CGFloat.pi * (3 - sqrt(5))
        static let radiusPaddingRatio: CGFloat = 0.02
        static let minimumPadding: CGFloat = 1
        static let maximumSpiralAttempts = 10_000
    }

    private struct IndexedEntry {
        let index: Int
        let entry: ReportEntry
    }

    /// 金額比を保ったまま、すべての円を表示領域へ収められる配置を返します。
    ///
    /// 先に金額の大きい円から決定的ならせん上へ置き、最後に全体を一様に縮小します。
    /// 一様な縮小なら円同士の非重複と面積比を同時に維持できるためです。
    static func layout(entries: [ReportEntry], in size: CGSize) -> [BubbleNode] {
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
        let radialStep = maximumRadius * 2 + padding

        var nodes: [BubbleNode] = []
        for (offset, indexedEntry) in validEntries.enumerated() {
            let radius = unscaledRadii[offset]
            let center: CGPoint
            if nodes.isEmpty {
                center = CGPoint(x: 0, y: 0)
            } else {
                center = spiralCenter(
                    radius: radius,
                    radialStep: radialStep,
                    padding: padding,
                    existingNodes: nodes
                )
            }
            nodes.append(BubbleNode(id: indexedEntry.entry.id, center: center, radius: radius))
        }

        return fitted(nodes, in: size)
    }

    private static func spiralCenter(
        radius: CGFloat,
        radialStep: CGFloat,
        padding: CGFloat,
        existingNodes: [BubbleNode]
    ) -> CGPoint {
        for attempt in 1...Constants.maximumSpiralAttempts {
            let angle = CGFloat(attempt) * Constants.goldenAngle
            let distance = radialStep * sqrt(CGFloat(attempt))
            let candidate = CGPoint(
                x: cos(angle) * distance,
                y: sin(angle) * distance
            )
            if existingNodes.allSatisfy({ node in
                hypot(candidate.x - node.center.x, candidate.y - node.center.y)
                    >= radius + node.radius + padding
            }) {
                return candidate
            }
        }

        let rightEdge = existingNodes.map { $0.center.x + $0.radius }.max() ?? 0
        return CGPoint(x: rightEdge + padding + radius, y: 0)
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
                radius: node.radius * scale
            )
        }
    }
}
