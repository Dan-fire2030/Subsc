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

    /// 次の期日に出ていく額です。時間軸（`UpcomingTimeline`）で使います。
    ///
    /// **年払いは年額をそのまま返します。** 次に出ていくのは1/12ではなく全額だからです
    /// （一覧の行やレポートの扱いとも揃えています）。
    /// 停止中の費目は出ていかないので `nil` にします。
    ///
    /// **変動費は金額を返しません（2026-08-08に修正）。** 次回の請求額は決まっておらず、
    /// ここで返していた `monthlyYen` は `originalAmount` 由来の別の値でした。
    /// 通知（`NotificationService.renewalBody`）も同じ理由で金額を書きません。
    /// **片方だけが額を出すと、同じアプリの中で言うことが食い違います。**
    var nextDueAmount: Double? {
        switch self {
        case .subscription(let subscription):
            guard subscription.state == .active else { return nil }
            guard !subscription.hasVariableAmount else { return nil }
            return subscription.billingCycle == .yearly
                ? subscription.yenAmount
                : subscription.monthlyYen
        case .loan(let loan, let summary):
            guard !loan.isPaused, !summary.isCompleted else { return nil }
            return summary.nextAmount
        }
    }

    /// 検索候補で名前の下に出す補足です。費目はカテゴリ、借入は返済方式を指します。
    var searchSubtitle: String {
        switch self {
        case .subscription(let subscription): subscription.category
        case .loan(let loan, _): loan.method.title
        }
    }

    /// 一覧の行に出している金額です。
    ///
    /// **`SubscriptionRow` の表示と同じ値を返します。** 並び替えの基準と見出しの合計は
    /// どちらもこれを使います。行に出ている数字と別の値で並べたり足したりすると、
    /// 「大きい順のはずなのに小さいものが上にある」ように見えます。
    ///
    /// 停止中や変動費でも値を返します。`nextDueAmount` と違い、
    /// **これは「次に出ていく額」ではなく「行に書いてある額」**だからです。
    var listedAmount: Double {
        switch self {
        case .subscription(let subscription):
            subscription.billingCycle == .yearly
                ? subscription.yenAmount
                : subscription.monthlyYen
        case .loan(_, let summary):
            summary.nextAmount
        }
    }

    /// どのセクションへ入るかです。
    var sectionKind: DashboardSectionKind {
        switch self {
        case .subscription(let subscription):
            subscription.billingCycle == .yearly ? .yearly : .monthly
        case .loan:
            .loan
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
        sortOrder: DashboardSortOrder = .dueDate,
        isDescending: Bool = false,
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
            .filter { matchesState(loan: $0.0, summary: $0.1, filter: stateFilter) }
            .filter { matchesQuery($0.0, query: normalizedQuery) }
            .map(DashboardListItem.loan)

        return sorted(
            subscriptionItems + loanItems,
            by: sortOrder,
            isDescending: isDescending
        )
    }

    /// 見出しごとに行をまとめます。
    ///
    /// **検索中はまとめません。** 探している最中に階層が増えると、目的の行が遠くなります。
    /// その場合は見出しを出さない印として `kind` が `nil` の1セクションを返します。
    ///
    /// **中身が空のセクションは作りません。** 見出しだけが並ぶのを避けるためです。
    /// 並び順は呼び出し前に決まっているので、ここでは順序に触れません。
    static func sections(
        from items: [DashboardListItem],
        isSearching: Bool
    ) -> [DashboardListSection] {
        guard !items.isEmpty else { return [] }
        guard !isSearching else {
            return [DashboardListSection(kind: nil, items: items)]
        }

        return DashboardSectionKind.allCases.compactMap { kind in
            let matching = items.filter { $0.sectionKind == kind }
            guard !matching.isEmpty else { return nil }
            return DashboardListSection(kind: kind, items: matching)
        }
    }

    /// 検索語が入っているか。**前後の空白だけの入力は検索と見なしません。**
    /// 空白を1つ打った瞬間にレポートが消えると、打ち間違えただけで画面を見失います。
    static func isSearching(query: String) -> Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 一覧に効かせる状態（利用中／停止中／履歴）の絞り込みです。
    ///
    /// **検索中は絞り込みを外します。** 理由は2つあります。
    /// 候補（`suggestions`）は状態を見ないため、一覧側だけ絞ると
    /// 「候補に出たのに選ぶと見つかりません」になります。
    /// また検索中はピッカーを画面から隠すため、絞り込みが効いたままだと
    /// 出てこない理由が画面のどこにも残りません。
    ///
    /// **種別（`CostTypeFilter`）は外しません。** ツールバーに出たままなので、
    /// 勝手に外すと画面の表示と結果が食い違います。
    static func effectiveStateFilter(
        _ filter: SubscriptionFilter,
        query: String
    ) -> SubscriptionFilter {
        isSearching(query: query) ? .all : filter
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
        upcomingItems(
            subscriptions: subscriptions,
            loans: loans,
            costTypeFilter: costTypeFilter,
            now: now,
            calendar: calendar
        )
        .first
    }

    /// 時間軸（`UpcomingTimeline`）に並べる、**これから期日が来るもの**です。
    ///
    /// **過ぎた期日を外します（2026-08-08に修正）。** 以前は期日の有無しか見ておらず、
    /// 「これから出ていく」の見出しの下に「期日超過」が並びえました。
    /// 更新日の繰り越しは起動時に走りますが、保存に失敗して巻き戻った場合や、
    /// 繰り越しが終わる前の描画では過去日が残ります。
    ///
    /// **`nextDue` と同じ判定です。** 別々に書くと、片方だけ直して食い違います。
    static func upcomingItems(
        subscriptions: [Subscription],
        loans: [Loan],
        costTypeFilter: CostTypeFilter,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DashboardListItem] {
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
        .filter { item in
            guard let dueDate = item.nextDueDate else { return false }
            return calendar.startOfDay(for: dueDate) >= today
        }
    }

    /// 選ばれた並び順で並べます。
    ///
    /// **どの並びでも、決着が付かないときは必ず名前で決めます。**
    /// 順序が決まらない組が残ると、再描画のたびに行が入れ替わります。
    ///
    /// **名前の決着は向きを反転しても昇順のままにします。** ここまで反転させると、
    /// 金額が同じ行だけが向きを変えるたびに入れ替わり、動きの理由が読めなくなります。
    private static func sorted(
        _ items: [DashboardListItem],
        by order: DashboardSortOrder,
        isDescending: Bool
    ) -> [DashboardListItem] {
        items.sorted { first, second in
            // **期日が無いものは、向きにかかわらず末尾へ送ります。**
            // 反転の対象に含めると「まだ予定表を作っていない借入」が先頭に来て、
            // 一覧の意味が壊れます。向きを掛ける前にここで決着させます。
            if order == .dueDate {
                switch (first.nextDueDate, second.nextDueDate) {
                case (nil, _?): return false
                case (_?, nil): return true
                default: break
                }
            }

            switch compare(first, second, by: order) {
            case .orderedSame:
                return isAscendingByName(first, second)
            case .orderedAscending:
                return !isDescending
            case .orderedDescending:
                return isDescending
            }
        }
    }

    private static func compare(
        _ first: DashboardListItem,
        _ second: DashboardListItem,
        by order: DashboardSortOrder
    ) -> ComparisonResult {
        switch order {
        case .dueDate:
            return compareDueDate(first, second)
        case .amount:
            if first.listedAmount == second.listedAmount { return .orderedSame }
            return first.listedAmount < second.listedAmount ? .orderedAscending : .orderedDescending
        case .name:
            // 日本語の並びで比べます。文字コード順だと、ひらがな・カタカナ・漢字が
            // 直感と違う順に出ます。
            return first.name.localizedStandardCompare(second.name)
        }
    }

    /// 期日順です。**期日が無い組は `sorted` で先に決着させている**ため、ここでは同着として扱います。
    private static func compareDueDate(
        _ first: DashboardListItem,
        _ second: DashboardListItem
    ) -> ComparisonResult {
        guard let lhs = first.nextDueDate, let rhs = second.nextDueDate else {
            return .orderedSame
        }
        if lhs == rhs { return .orderedSame }
        return lhs < rhs ? .orderedAscending : .orderedDescending
    }

    private static func isAscendingByName(
        _ first: DashboardListItem,
        _ second: DashboardListItem
    ) -> Bool {
        first.name.localizedStandardCompare(second.name) == .orderedAscending
    }

    // MARK: - 費目

    /// 終了日を過ぎた費目を履歴として扱う既存の挙動を、そのまま持ってきています。
    private static func matchesState(
        _ subscription: Subscription,
        filter: SubscriptionFilter,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        // **アーカイブ中は「アーカイブ」の段だけに出します。**
        // 「すべて」にも出さないのは、アーカイブが「一覧から消したもの」だからです。
        // ここに出すと退けた意味がなくなります。判定はどの段よりも先に行います。
        let isArchived = ArchivePolicy.isArchived(subscription.archivedAt)
        guard filter != .archived else { return isArchived }
        guard !isArchived else { return false }

        let isHistory = subscription.endDate.map { $0 < calendar.startOfDay(for: now) } ?? false
        switch filter {
        case .all: return true
        case .active: return subscription.state == .active && !isHistory
        case .paused: return subscription.state == .paused && !isHistory
        case .history: return isHistory
        case .archived: return false
        }
    }

    private static func matchesQuery(_ subscription: Subscription, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return subscription.name.localizedCaseInsensitiveContains(query)
            || subscription.category.localizedCaseInsensitiveContains(query)
            || subscription.notes.localizedCaseInsensitiveContains(query)
    }

    // MARK: - 借入

    /// 完済していれば履歴、返済を止めていれば停止中、それ以外は利用中として扱います。
    ///
    /// **完済を停止より先に見ます。** 完済した借入は止められないため両方が立つことはありませんが、
    /// 過去に止めたまま完済したデータが残っていても、履歴として1箇所に出ます。
    private static func matchesState(
        loan: Loan,
        summary: LoanSummary,
        filter: SubscriptionFilter
    ) -> Bool {
        // 費目と同じ規則です。アーカイブ中は「アーカイブ」の段だけに出します。
        let isArchived = ArchivePolicy.isArchived(loan.archivedAt)
        guard filter != .archived else { return isArchived }
        guard !isArchived else { return false }

        switch filter {
        case .all: return true
        case .active: return !summary.isCompleted && !loan.isPaused
        case .paused: return !summary.isCompleted && loan.isPaused
        case .history: return summary.isCompleted
        case .archived: return false
        }
    }

    private static func matchesQuery(_ loan: Loan, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return loan.name.localizedCaseInsensitiveContains(query)
            || loan.note.localizedCaseInsensitiveContains(query)
    }
}
