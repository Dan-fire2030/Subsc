import Foundation

struct CostTypeSlice: Identifiable, Equatable {
    let costType: CostType
    let amount: Double
    let isEstimated: Bool

    var id: String { costType.rawValue }
}

enum CostTypeBreakdown {
    private struct Accumulator {
        var amount: Double = 0
        var isEstimated = false
    }

    /// 種別ごとの構成比を一貫した順序で描けるよう、費目を集計して返します。
    static func slices(from entries: [ReportEntry]) -> [CostTypeSlice] {
        let totals = entries.reduce(into: [CostType: Accumulator]()) { result, entry in
            result[entry.costType, default: Accumulator()].amount += entry.amount
            result[entry.costType, default: Accumulator()].isEstimated =
                result[entry.costType, default: Accumulator()].isEstimated || entry.isEstimated
        }

        return CostType.allCases
            .compactMap { costType -> CostTypeSlice? in
                guard let total = totals[costType], total.amount > 0 else { return nil }
                return CostTypeSlice(
                    costType: costType,
                    amount: total.amount,
                    isEstimated: total.isEstimated
                )
            }
            .sorted { first, second in
                if first.amount == second.amount {
                    let firstIndex = CostType.allCases.firstIndex(of: first.costType) ?? 0
                    let secondIndex = CostType.allCases.firstIndex(of: second.costType) ?? 0
                    return firstIndex < secondIndex
                }
                return first.amount > second.amount
            }
    }
}
