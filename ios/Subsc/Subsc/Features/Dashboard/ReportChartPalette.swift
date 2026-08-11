import SwiftUI

struct ReportChartItem: Identifiable, Equatable {
    let id: String
    let name: String
    let amount: Double
    let colorHex: String
    let isEstimated: Bool
    let opacity: Double
}

enum ReportChartPalette {
    /// 見込みを色だけでなく濃さでも一貫して区別できるよう、全グラフで同じ値を使います。
    static let estimatedOpacity = 0.45
    static let confirmedOpacity = 1.0

    /// 集計単位と色をここで確定し、ビュー内の条件分岐を防ぎます。
    ///
    /// **集計単位はスタイルではなく期間で決まります。**
    /// 年間換算は「1年で何にいくら使ったか」の大づかみを見たいので種別へまとめ、
    /// 月間換算は「今月どの費目が効いているか」を見たいので費目のまま出します。
    ///
    /// ただし**種別で絞り込んでいるときは年間でも費目ごと**にします。
    /// 種別が1つしかない状態で種別集計すると、区画が1つだけになり構成比の情報が消えるためです。
    static func items(
        from entries: [ReportEntry],
        filter: CostTypeFilter,
        period: ReportPeriod
    ) -> [ReportChartItem] {
        let aggregatesByCostType = period == .year && filter == .all

        guard aggregatesByCostType else {
            return entries
                .sorted(by: descendingAmount)
                .map { entry in
                    ReportChartItem(
                        id: entry.id,
                        name: entry.name,
                        amount: entry.amount,
                        colorHex: entry.colorHex,
                        isEstimated: entry.isEstimated,
                        opacity: opacity(isEstimated: entry.isEstimated)
                    )
                }
        }

        return CostTypeBreakdown.slices(from: entries).map { slice in
            ReportChartItem(
                id: slice.id,
                name: slice.costType.title,
                amount: slice.amount,
                colorHex: slice.costType.colorHex,
                isEstimated: slice.isEstimated,
                opacity: opacity(isEstimated: slice.isEstimated)
            )
        }
    }

    /// 内訳シートの見本に使う色の元です。
    ///
    /// **グラフ本体と同じ寄せ方を通します。** 2026-08-11まで内訳シートだけが
    /// 保存値（`ColorHex.color(from:)`）で描いており、**同じ費目がグラフと内訳で違う色**に
    /// 見えていました。寄せ先を1つにするため、ここを唯一の出どころにします。
    static func breakdownBaseHex(for colorHex: String) -> String {
        BlackCatPalette.harmonizedHex(from: colorHex)
    }

    /// 内訳シートの見本のグラデーションです。
    ///
    /// **段の作りは変えません**（元の色 → 同じ色の55% → 面）。色の出どころだけを揃えています。
    static func breakdownSwatchColors(for colorHex: String) -> [Color] {
        let base = ColorHex.color(from: breakdownBaseHex(for: colorHex))
        return [base, base.opacity(0.55), BlackCatPalette.surfaceElevated]
    }

    static func color(for item: ReportChartItem) -> Color {
        // **保存値ではなく、黒猫のパレットへ寄せた色で描きます。**
        // 旧プリセット（iOS標準色）で保存された費目がそのままだと、
        // 画面の主役であるグラフだけ配色が取り残されます。保存値は書き換えません。
        BlackCatPalette.harmonized(from: item.colorHex).opacity(item.opacity)
    }

    static func fraction(for item: ReportChartItem, total: Double) -> Double {
        guard total > 0 else { return 0 }
        return max(0, min(1, item.amount / total))
    }

    /// 小さな要素を消さず、同時に全要素を必ず利用可能幅へ収めます。
    static func lengths(
        for items: [ReportChartItem],
        availableLength: CGFloat,
        minimumLength: CGFloat
    ) -> [CGFloat] {
        guard !items.isEmpty, availableLength > 0 else { return [] }
        let minimumTotal = minimumLength * CGFloat(items.count)
        guard availableLength > minimumTotal else {
            return Array(repeating: availableLength / CGFloat(items.count), count: items.count)
        }

        let total = items.reduce(0) { $0 + max(0, $1.amount) }
        guard total > 0 else {
            return Array(repeating: availableLength / CGFloat(items.count), count: items.count)
        }
        let distributable = availableLength - minimumTotal
        return items.map { item in
            minimumLength + distributable * CGFloat(max(0, item.amount) / total)
        }
    }

    private static func opacity(isEstimated: Bool) -> Double {
        isEstimated ? estimatedOpacity : confirmedOpacity
    }

    private static func descendingAmount(_ first: ReportEntry, _ second: ReportEntry) -> Bool {
        if first.amount == second.amount {
            return first.id < second.id
        }
        return first.amount > second.amount
    }
}
