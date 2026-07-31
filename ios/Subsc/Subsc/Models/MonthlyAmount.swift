import Foundation

/// ある年月に、その費目がいくらだったかを解決した結果です。
///
/// 金額だけでなく**どうやって決めた額なのか**を持ちます。見込みの額を実績と同じ顔で
/// 表示すると、利用者が「記録済みだ」と誤解してしまうためです。
struct MonthlyAmount: Equatable {
    enum Source: String, Equatable {
        /// その月の実績、または定額の費目。
        case recorded
        /// その月の実績が無く、直近の実績から見込んだ額。
        case estimated
        /// 実績が1件も無く、金額を出せない。
        case unavailable
    }

    let amount: Double
    let source: Source

    static let unavailable = MonthlyAmount(amount: 0, source: .unavailable)
}

/// 変動費の月次実績から「その月いくらか」を決めます。
///
/// 決め方はSPEC R3の3段階です。
/// 1. その月の実績があればその額
/// 2. 無ければ、**その月より前で**最も新しい実績の額（見込み）
/// 3. それも無ければ0円
///
/// あとの月の実績を前の月に持ってこないのは、記録を始める前の月に
/// 払っていない額を計上してしまうためです。
enum MonthlyAmountResolver {
    static func resolve(entries: [AmountEntry], periodKey: Int) -> MonthlyAmount {
        if let exact = entries.first(where: { $0.periodKey == periodKey }) {
            return MonthlyAmount(amount: exact.amount, source: .recorded)
        }

        let latestEarlier = entries
            .filter { $0.periodKey < periodKey }
            .max { $0.periodKey < $1.periodKey }

        guard let latestEarlier else { return .unavailable }
        return MonthlyAmount(amount: latestEarlier.amount, source: .estimated)
    }
}
