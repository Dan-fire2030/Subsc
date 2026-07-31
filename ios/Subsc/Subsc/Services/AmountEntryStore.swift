import Foundation

/// 変動費の月次実績を読み書きします。
///
/// **同じ年月の実績が2件できないことを保証するのがこの型の役目です。**
/// CloudKitミラーリングでは `@Attribute(.unique)` を使えないため、
/// 一意性はデータベースではなくここで保つしかありません。
/// 実績を作る処理はすべてここを通してください。
///
/// ただし2台の端末がオフラインで同じ月を記録した場合は、同期後に2件並びます。
/// これはアプリ側では防げないため、**記録時に同じ年月の全件を同じ金額へ揃え**、
/// 読み出し側（`MonthlyAmountResolver.winner`）でも決定的に1件を選ぶ二段構えにしています。
enum AmountEntryStore {
    /// その年月の実績を記録します。すでにあれば金額を書き換え、無ければ追加します。
    ///
    /// 通貨と為替レートは**記録時点の値を実績側に写し取ります**。費目の通貨やレートは
    /// あとから変わるため、それを参照すると過去月の金額が動いてしまいます。
    @discardableResult
    static func record(
        amount: Double,
        year: Int,
        month: Int,
        currency: SubscriptionCurrency? = nil,
        exchangeRate: Double? = nil,
        on subscription: Subscription,
        recordedAt: Date = .now
    ) -> AmountEntry? {
        guard (1...12).contains(month), year > 0 else { return nil }

        let periodKey = year * 100 + month
        let recordedCurrency = currency ?? subscription.currency
        let recordedExchangeRate = exchangeRate ?? subscription.exchangeRate
        subscription.updatedAt = recordedAt

        let existing = entries(on: subscription, periodKey: periodKey)
        if !existing.isEmpty {
            // 同期で重複していた場合も、全件を同じ値へ揃えてどれが選ばれても同じにします。
            for entry in existing {
                entry.amount = amount
                entry.currency = recordedCurrency
                entry.exchangeRate = recordedExchangeRate
                entry.recordedAt = recordedAt
            }
            return MonthlyAmountResolver.winner(among: existing)
        }

        let entry = AmountEntry(
            year: year,
            month: month,
            amount: amount,
            currency: recordedCurrency,
            exchangeRate: recordedExchangeRate,
            recordedAt: recordedAt
        )
        // 逆リレーションはSwiftDataが張るため、片側だけ更新します。
        // 両側に入れると同じ実績が2件並ぶ可能性があります。
        subscription.amountEntries = (subscription.amountEntries ?? []) + [entry]
        return entry
    }

    /// その年月の実績です。同期の重複があれば複数返ります。
    static func entries(on subscription: Subscription, periodKey: Int) -> [AmountEntry] {
        (subscription.amountEntries ?? []).filter { $0.periodKey == periodKey }
    }

    /// その年月で採用される実績です。重複があっても決定的に1件を選びます。
    static func entry(on subscription: Subscription, periodKey: Int) -> AmountEntry? {
        MonthlyAmountResolver.winner(among: entries(on: subscription, periodKey: periodKey))
    }

    static func hasRecord(on subscription: Subscription, periodKey: Int) -> Bool {
        !entries(on: subscription, periodKey: periodKey).isEmpty
    }
}
