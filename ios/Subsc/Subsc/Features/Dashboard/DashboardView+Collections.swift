import Foundation

/// `DashboardView` が画面に並べる材料です。`body` から切り出しただけで、意味は元のまま保っています。
///
/// **並び順と絞り込みの条件そのものは `DashboardListBuilder` に閉じています。**
/// ここにあるのは「どの母集団を渡すか」の判断だけです。
extension DashboardView {
    /// 種別で絞り込んだ費目です。レポートと一覧の両方がここを起点にします。
    var subscriptionsInSelectedTypes: [Subscription] {
        subscriptions.filter { costTypeFilter.matches($0) }
    }

    /// 種別で絞り込んだ借入です。借入の種別は常に `.loan` なので、丸ごと通すか外すかの二択です。
    var loansInSelectedTypes: [Loan] {
        costTypeFilter.matches(.loan) ? loans : []
    }

    /// 一覧に並べる要素です。**費目と借入を「次の期日」で1本に混ぜます。**
    var visibleItems: [DashboardListItem] {
        DashboardListBuilder.items(
            subscriptions: subscriptions,
            loans: loans,
            stateFilter: filter,
            costTypeFilter: costTypeFilter,
            query: query
        )
    }

    /// 登録が1件も無いか。空の案内を出すかどうかの判断に使います。
    var hasNoRegistrations: Bool {
        subscriptions.isEmpty && loans.isEmpty
    }

    /// 検索候補です。**費目と借入の両方**が出ます。
    var searchSuggestions: [DashboardListItem] {
        DashboardListBuilder.suggestions(
            subscriptions: subscriptions,
            loans: loans,
            costTypeFilter: costTypeFilter,
            query: query
        )
    }

    /// 時間軸に並べる、これから期日が来るものです。
    ///
    /// **期日を持たないもの（完済した借入など）は外します。** 軸の上に置けないためです。
    var upcomingItems: [DashboardListItem] {
        DashboardListBuilder.items(
            subscriptions: subscriptions,
            loans: loans,
            stateFilter: .active,
            costTypeFilter: costTypeFilter,
            query: ""
        )
        .filter { $0.nextDueDate != nil }
    }

    /// 相棒の黒猫がいまどの姿で座るかです。
    ///
    /// **種別の絞り込みを掛けた母集団で判断します。** レポートと違う材料で表情を決めると、
    /// 画面に出ている金額と猫の様子が食い違って見えます。
    var catMood: CatMood {
        CatMoodContext.mood(
            subscriptions: subscriptionsInSelectedTypes,
            loans: loansInSelectedTypes
        )
    }

    /// この先の月に来る、年払いのまとまった支払いです。
    /// **種別の絞り込みに従います。** レポートと違う母集団を出すと、金額が合わなく見えます。
    var upcomingCharges: [UpcomingChargeNotice] {
        UpcomingLargeCharge.notices(subscriptions: subscriptionsInSelectedTypes)
    }

    /// 為替レートの更新は表示上の種別絞り込みと無関係なため、全費目の米ドル契約を監視します。
    var usdSubscriptionIDs: String {
        subscriptions
            .filter { $0.currency == .usd }
            .map(\.clientID)
            .sorted()
            .joined(separator: ",")
    }
}
