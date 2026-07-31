import Foundation
import SwiftData

/// 金額が毎月変わる費目の「その月いくらだったか」の記録です。
///
/// 光熱費のように毎月額が違うものは、1つの固定額では過去のレポートが実態と合わなくなります。
/// 月ごとに実績を積み上げることで、過去月のレポートが実際に支払った額になります。
///
/// CloudKitミラーリングの制約に合わせ、**すべての保存プロパティに既定値を持たせ、
/// 一意制約は使っていません**。同じ年月の記録が2件できないことは、
/// 保存時に既存を探して上書きすることで保ちます（`AmountEntryStore`）。
@Model
final class AmountEntry {
    var clientID: String = UUID().uuidString
    var year: Int = 0
    var month: Int = 0
    var amount: Double = 0
    var recordedAt: Date = Date.now
    /// 逆リレーション。CloudKitミラーリングはリレーションを非Optionalにできないため Optional です。
    var subscription: Subscription?

    init(
        clientID: String = UUID().uuidString,
        year: Int,
        month: Int,
        amount: Double,
        recordedAt: Date = .now
    ) {
        self.clientID = clientID
        self.year = year
        self.month = month
        self.amount = amount
        self.recordedAt = recordedAt
    }

    /// 並べ替えと比較に使う、年月を1つの整数にした値です（例：2026年7月 → 202607）。
    var periodKey: Int { year * 100 + month }
}

extension AmountEntry {
    /// その日付が属する年月のキーを返します。実績の検索条件をここに集約しています。
    static func periodKey(for date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.year, .month], from: date)
        return (components.year ?? 0) * 100 + (components.month ?? 0)
    }
}
