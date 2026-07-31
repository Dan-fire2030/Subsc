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
        if let exact = winner(among: entries.filter { $0.periodKey == periodKey }) {
            return MonthlyAmount(amount: exact.yenAmount, source: .recorded)
        }

        let earlier = entries.filter { $0.periodKey < periodKey }
        guard let latestPeriodKey = earlier.map(\.periodKey).max(),
              let latestEarlier = winner(
                among: earlier.filter { $0.periodKey == latestPeriodKey }
              ) else {
            return .unavailable
        }
        return MonthlyAmount(amount: latestEarlier.yenAmount, source: .estimated)
    }

    /// 同じ年月に複数の実績があるときに、どれを採用するかを**決定的に**選びます。
    ///
    /// CloudKitでは一意制約が使えないため、2台の端末がオフラインで同じ月を記録すると
    /// 両方が残ります。`first` で拾うと配列順しだいで金額が変わってしまうので、
    /// 「あとに記録したもの」を勝ちとし、同時刻なら識別子で決めます。
    static func winner(among entries: [AmountEntry]) -> AmountEntry? {
        entries.max {
            $0.recordedAt == $1.recordedAt
                ? $0.clientID < $1.clientID
                : $0.recordedAt < $1.recordedAt
        }
    }
}
