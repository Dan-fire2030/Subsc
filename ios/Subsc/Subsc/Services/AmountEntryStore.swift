import Foundation

/// 変動費の月次実績を読み書きします。
///
/// **同じ年月の実績が2件できないことを保証するのがこの型の役目です。**
/// CloudKitミラーリングでは `@Attribute(.unique)` を使えないため、
/// 一意性はデータベースではなくここで保つしかありません。
/// 実績を作る処理はすべてここを通してください。
enum AmountEntryStore {
    /// その年月の実績を記録します。すでにあれば金額を書き換え、無ければ追加します。
    @discardableResult
    static func record(
        amount: Double,
        year: Int,
        month: Int,
        on subscription: Subscription,
        recordedAt: Date = .now
    ) -> AmountEntry {
        let periodKey = year * 100 + month
        subscription.updatedAt = recordedAt

        if let existing = entry(on: subscription, periodKey: periodKey) {
            existing.amount = amount
            existing.recordedAt = recordedAt
            return existing
        }

        let entry = AmountEntry(
            year: year,
            month: month,
            amount: amount,
            recordedAt: recordedAt
        )
        // 逆リレーションはSwiftDataが張るため、片側だけ更新します。
        // 両側に入れると同じ実績が2件並ぶ可能性があります。
        subscription.amountEntries = (subscription.amountEntries ?? []) + [entry]
        return entry
    }

    static func entry(on subscription: Subscription, periodKey: Int) -> AmountEntry? {
        subscription.amountEntries?.first { $0.periodKey == periodKey }
    }

    static func hasRecord(on subscription: Subscription, periodKey: Int) -> Bool {
        entry(on: subscription, periodKey: periodKey) != nil
    }
}
