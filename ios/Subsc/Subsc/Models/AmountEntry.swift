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
    /// 記録した時点の通貨です。
    ///
    /// **費目側の通貨を参照してはいけません。** 費目の通貨を後から変えると、
    /// 過去に円で記録した実績がドルとして解釈されてしまいます。
    var currencyRaw: String = SubscriptionCurrency.jpy.rawValue
    /// 記録した時点の為替レートです。
    ///
    /// 費目の `exchangeRate` は最新レートで随時上書きされるため、これを使って過去月を
    /// 換算すると、**支払い済みの月の金額が今日のレートで変動してしまいます。**
    var exchangeRate: Double = 1
    var recordedAt: Date = Date.now
    /// 逆リレーション。CloudKitミラーリングはリレーションを非Optionalにできないため Optional です。
    var subscription: Subscription?

    init(
        clientID: String = UUID().uuidString,
        year: Int,
        month: Int,
        amount: Double,
        currency: SubscriptionCurrency = .jpy,
        exchangeRate: Double = 1,
        recordedAt: Date = .now
    ) {
        self.clientID = clientID
        self.year = year
        self.month = month
        self.amount = amount
        self.currencyRaw = currency.rawValue
        self.exchangeRate = exchangeRate
        self.recordedAt = recordedAt
    }

    var currency: SubscriptionCurrency {
        get { SubscriptionCurrency(rawValue: currencyRaw) ?? .jpy }
        set { currencyRaw = newValue.rawValue }
    }

    /// 記録時のレートで円に換算した金額です。あとから為替レートが動いても変わりません。
    var yenAmount: Double {
        currency == .usd ? amount * exchangeRate : amount
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

    /// 年月キーから月だけを取り出します（例：202607 → 7）。
    static func month(fromPeriodKey periodKey: Int) -> Int {
        periodKey % 100
    }
}
