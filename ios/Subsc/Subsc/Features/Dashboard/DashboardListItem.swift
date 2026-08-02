import Foundation

/// 一覧に並ぶ1件です。
///
/// 費目（`Subscription`）と借入（`Loan`）は別のモデルですが、利用者から見ればどちらも
/// 「毎月お金が出ていくもの」です。**同じ「次の期日」で1本のリストへ混ぜる**ため、
/// 表示に必要な差分だけをこの型で吸収します。
enum DashboardListItem: Identifiable {
    case subscription(Subscription)
    /// 要約を一緒に持ちます。残高や次回返済日は行と詳細で何度も使うため、
    /// 組み立てのときに1度だけ計算します。
    case loan(Loan, LoanSummary)

    /// **種別ごとに接頭辞を付けます。** 費目と借入で `clientID` が偶然衝突しても、
    /// `ForEach` が同じ行だと誤認しないようにするためです。
    var id: String {
        switch self {
        case .subscription(let subscription): "subscription-\(subscription.clientID)"
        case .loan(let loan, _): "loan-\(loan.clientID)"
        }
    }

    var name: String {
        switch self {
        case .subscription(let subscription): subscription.name
        case .loan(let loan, _): loan.name
        }
    }

    var costType: CostType {
        switch self {
        case .subscription(let subscription): subscription.costType
        case .loan: .loan
        }
    }

    /// 並べ替えに使う「次の期日」です。費目は更新日、借入は次回返済日を指します。
    var nextDueDate: Date? {
        switch self {
        case .subscription(let subscription): subscription.renewalDate
        case .loan(_, let summary): summary.nextDueDate
        }
    }

    /// 検索候補で名前の下に出す補足です。費目はカテゴリ、借入は返済方式を指します。
    var searchSubtitle: String {
        switch self {
        case .subscription(let subscription): subscription.category
        case .loan(let loan, _): loan.method.title
        }
    }
}

/// 一覧に並べる要素を組み立てます。
///
/// **並び順と絞り込みの条件をビューから追い出すため**の型です。ビューに書くと、
/// 種別が増えるたびに同じ条件が画面のあちこちへ散らばります。
enum DashboardListBuilder {
    static func items(
        subscriptions: [Subscription],
        loans: [Loan],
        stateFilter: SubscriptionFilter,
        costTypeFilter: CostTypeFilter,
        query: String,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DashboardListItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let subscriptionItems = subscriptions
            .filter { costTypeFilter.matches($0.costType) }
            .filter { matchesState($0, filter: stateFilter, now: now, calendar: calendar) }
            .filter { matchesQuery($0, query: normalizedQuery) }
            .map(DashboardListItem.subscription)

        // 借入の種別は常に `.loan` なので、1件ずつではなく最初に一度だけ判定します。
        let loanItems = (costTypeFilter.matches(.loan) ? loans : [])
            .map { ($0, LoanSummary.make(for: $0)) }
            .filter { matchesState(summary: $0.1, filter: stateFilter) }
            .filter { matchesQuery($0.0, query: normalizedQuery) }
            .map(DashboardListItem.loan)

        return sorted(subscriptionItems + loanItems)
    }

    /// 検索フィールドに出す候補です。
    ///
    /// **費目と借入の両方を対象にします。** 片方しか出さないと、打っている最中に
    /// 「見つからない」と受け取られます（借入を追加した当初がこの状態でした）。
    /// 利用中・停止中の絞り込みは効かせません。候補は現在の表示状態と関係なく探せるほうが速いためです。
    static func suggestions(
        subscriptions: [Subscription],
        loans: [Loan],
        costTypeFilter: CostTypeFilter,
        query: String,
        limit: Int = 6,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DashboardListItem] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return Array(
            items(
                subscriptions: subscriptions,
                loans: loans,
                stateFilter: .all,
                costTypeFilter: costTypeFilter,
                query: query,
                now: now,
                calendar: calendar
            )
            .prefix(limit)
        )
    }

    /// 次に支払いが来る1件です。
    ///
    /// **費目の更新日と借入の返済日を同じ土俵で比べます。** 片方しか見ないと、
    /// 明日が返済日の借入があっても「次の支払い」に出てきません。
    /// 停止中の費目と完済した借入は、もう支払いが来ないので対象外です。
    static func nextDue(
        subscriptions: [Subscription],
        loans: [Loan],
        costTypeFilter: CostTypeFilter,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DashboardListItem? {
        let today = calendar.startOfDay(for: now)
        return items(
            subscriptions: subscriptions,
            loans: loans,
            stateFilter: .active,
            costTypeFilter: costTypeFilter,
            query: "",
            now: now,
            calendar: calendar
        )
        .first { item in
            guard let dueDate = item.nextDueDate else { return false }
            return calendar.startOfDay(for: dueDate) >= today
        }
    }

    /// 期日の昇順に並べ、**期日が無いものは末尾**へ送ります。
    /// 同じ日付のときは名前で並べ、再描画のたびに順序が入れ替わらないようにします。
    private static func sorted(_ items: [DashboardListItem]) -> [DashboardListItem] {
        items.sorted { first, second in
            switch (first.nextDueDate, second.nextDueDate) {
            case let (lhs?, rhs?):
                if lhs != rhs { return lhs < rhs }
                return first.name.localizedCompare(second.name) == .orderedAscending
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            case (nil, nil):
                return first.name.localizedCompare(second.name) == .orderedAscending
            }
        }
    }

    // MARK: - 費目

    /// 終了日を過ぎた費目を履歴として扱う既存の挙動を、そのまま持ってきています。
    private static func matchesState(
        _ subscription: Subscription,
        filter: SubscriptionFilter,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        let isHistory = subscription.endDate.map { $0 < calendar.startOfDay(for: now) } ?? false
        switch filter {
        case .all: return true
        case .active: return subscription.state == .active && !isHistory
        case .paused: return subscription.state == .paused && !isHistory
        case .history: return isHistory
        }
    }

    private static func matchesQuery(_ subscription: Subscription, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return subscription.name.localizedCaseInsensitiveContains(query)
            || subscription.category.localizedCaseInsensitiveContains(query)
            || subscription.notes.localizedCaseInsensitiveContains(query)
    }

    // MARK: - 借入

    /// **借入に「停止中」はありません。** 完済していれば履歴、そうでなければ利用中として扱います。
    private static func matchesState(summary: LoanSummary, filter: SubscriptionFilter) -> Bool {
        switch filter {
        case .all: return true
        case .active: return !summary.isCompleted
        case .paused: return false
        case .history: return summary.isCompleted
        }
    }

    private static func matchesQuery(_ loan: Loan, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return loan.name.localizedCaseInsensitiveContains(query)
            || loan.note.localizedCaseInsensitiveContains(query)
    }
}
