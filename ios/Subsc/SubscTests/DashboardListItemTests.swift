import XCTest
@testable import Subsc

/// 費目と借入を**1本のリストへ混ぜる**組み立てのテストです。
///
/// 並び順と絞り込みをビューに書くと、種別を足すたびに条件が散らばります。
/// ここへ寄せて、種別が増えても1箇所で済むようにしています。
final class DashboardListItemTests: XCTestCase {
    private enum Fixture {
        static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt
            return calendar
        }

        static let now = DateComponents(
            calendar: calendar,
            year: 2026,
            month: 1,
            day: 15
        ).date ?? .distantPast
    }

    // MARK: - 並び順

    /// **費目の更新日と借入の次回返済日を同じ「次の期日」として扱い**、日付順に混ぜます。
    func testItemsAreMixedAndSortedByTheNextDueDate() throws {
        let subscription = makeSubscription(name: "動画", renewalOn: date(2026, 2, 10))
        let loan = try makeSynchronizedLoan(name: "自動車ローン")

        let items = DashboardListBuilder.items(
            subscriptions: [subscription],
            loans: [loan],
            stateFilter: .all,
            costTypeFilter: .all,
            query: "",
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        // 借入の1回目は 2026-01-27、費目の更新は 2026-02-10。
        XCTAssertEqual(items.map(\.name), ["自動車ローン", "動画"])
    }

    /// 期日が無いもの（予定表を作る前の借入）は末尾へ送ります。先頭に来ると一覧の意味が壊れます。
    func testItemsWithoutADueDateGoLast() {
        let subscription = makeSubscription(name: "動画", renewalOn: date(2026, 2, 10))
        let loan = Loan(name: "未設定ローン")

        let items = DashboardListBuilder.items(
            subscriptions: [subscription],
            loans: [loan],
            stateFilter: .all,
            costTypeFilter: .all,
            query: "",
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(items.map(\.name), ["動画", "未設定ローン"])
    }

    // MARK: - 種別の絞り込み

    func testFilteringByLoanKeepsOnlyLoans() throws {
        let subscription = makeSubscription(name: "動画", renewalOn: date(2026, 2, 10))
        let loan = try makeSynchronizedLoan(name: "自動車ローン")

        let items = DashboardListBuilder.items(
            subscriptions: [subscription],
            loans: [loan],
            stateFilter: .all,
            costTypeFilter: .only(.loan),
            query: "",
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(items.map(\.name), ["自動車ローン"])
    }

    /// 借入以外の種別で絞ると、借入は消えます。
    func testFilteringByAnotherCostTypeDropsLoans() throws {
        let subscription = makeSubscription(name: "動画", renewalOn: date(2026, 2, 10))
        let loan = try makeSynchronizedLoan(name: "自動車ローン")

        let items = DashboardListBuilder.items(
            subscriptions: [subscription],
            loans: [loan],
            stateFilter: .all,
            costTypeFilter: .only(.subscription),
            query: "",
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(items.map(\.name), ["動画"])
    }

    // MARK: - 状態の絞り込み

    /// 止めていない借入は「停止中」の絞り込みに出ません。
    func testRepayingLoansDoNotAppearUnderThePausedFilter() throws {
        let loan = try makeSynchronizedLoan(name: "自動車ローン")

        let items = DashboardListBuilder.items(
            subscriptions: [],
            loans: [loan],
            stateFilter: .paused,
            costTypeFilter: .all,
            query: "",
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertTrue(items.isEmpty)
    }

    /// **停止した借入は「停止中」で絞り込むと出ます。**
    /// ここに出ないと、止めたものを探す手段が無くなります。
    func testPausedLoanAppearsUnderThePausedFilter() throws {
        let loan = try makeSynchronizedLoan(name: "自動車ローン")
        try LoanPaymentStore.pause(loan: loan, on: Fixture.now, calendar: Fixture.calendar)

        let items = DashboardListBuilder.items(
            subscriptions: [],
            loans: [loan],
            stateFilter: .paused,
            costTypeFilter: .all,
            query: "",
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(items.map(\.name), ["自動車ローン"])
    }

    /// 停止した借入は「利用中」からは消えます。費目の停止中と同じ扱いです。
    func testPausedLoanDisappearsFromTheActiveFilter() throws {
        let loan = try makeSynchronizedLoan(name: "自動車ローン")
        try LoanPaymentStore.pause(loan: loan, on: Fixture.now, calendar: Fixture.calendar)

        let items = DashboardListBuilder.items(
            subscriptions: [],
            loans: [loan],
            stateFilter: .active,
            costTypeFilter: .all,
            query: "",
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertTrue(items.isEmpty)
    }

    /// 停止した借入は「次の支払い」にも出ません。止めているのに次の予定が出ると矛盾します。
    func testPausedLoanIsNotTheNextDue() throws {
        let loan = try makeSynchronizedLoan(name: "自動車ローン")
        try LoanPaymentStore.pause(loan: loan, on: Fixture.now, calendar: Fixture.calendar)

        let next = DashboardListBuilder.nextDue(
            subscriptions: [],
            loans: [loan],
            costTypeFilter: .all,
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertNil(next)
    }

    /// 完済した借入は「履歴」へ移り、「利用中」からは消えます。
    func testCompletedLoanMovesToHistory() throws {
        let loan = try makeSynchronizedLoan(name: "完済ローン")
        for payment in LoanPaymentStore.sortedPayments(on: loan) {
            payment.status = .paid
        }

        let active = DashboardListBuilder.items(
            subscriptions: [],
            loans: [loan],
            stateFilter: .active,
            costTypeFilter: .all,
            query: "",
            now: Fixture.now,
            calendar: Fixture.calendar
        )
        let history = DashboardListBuilder.items(
            subscriptions: [],
            loans: [loan],
            stateFilter: .history,
            costTypeFilter: .all,
            query: "",
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertTrue(active.isEmpty)
        XCTAssertEqual(history.map(\.name), ["完済ローン"])
    }

    /// 終了日を過ぎた費目が履歴へ移る既存の挙動は変えません。
    func testEndedSubscriptionStaysInHistory() {
        let subscription = makeSubscription(name: "解約済み", renewalOn: date(2025, 12, 10))
        subscription.endDate = date(2025, 12, 31)

        let history = DashboardListBuilder.items(
            subscriptions: [subscription],
            loans: [],
            stateFilter: .history,
            costTypeFilter: .all,
            query: "",
            now: Fixture.now,
            calendar: Fixture.calendar
        )
        let active = DashboardListBuilder.items(
            subscriptions: [subscription],
            loans: [],
            stateFilter: .active,
            costTypeFilter: .all,
            query: "",
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(history.map(\.name), ["解約済み"])
        XCTAssertTrue(active.isEmpty)
    }

    // MARK: - 検索

    func testQueryMatchesLoanNameAndNote() throws {
        let loan = try makeSynchronizedLoan(name: "自動車ローン")
        loan.note = "A銀行"

        let byName = DashboardListBuilder.items(
            subscriptions: [],
            loans: [loan],
            stateFilter: .all,
            costTypeFilter: .all,
            query: "自動車",
            now: Fixture.now,
            calendar: Fixture.calendar
        )
        let byNote = DashboardListBuilder.items(
            subscriptions: [],
            loans: [loan],
            stateFilter: .all,
            costTypeFilter: .all,
            query: "A銀行",
            now: Fixture.now,
            calendar: Fixture.calendar
        )
        let miss = DashboardListBuilder.items(
            subscriptions: [],
            loans: [loan],
            stateFilter: .all,
            costTypeFilter: .all,
            query: "住宅",
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(byName.count, 1)
        XCTAssertEqual(byNote.count, 1)
        XCTAssertTrue(miss.isEmpty)
    }

    // MARK: - 検索中の絞り込み範囲

    /// 前後の空白だけの入力は「検索していない」と見なします。
    /// 空白で画面から情報が消えると、打ち間違えただけで見失います。
    func testWhitespaceOnlyQueryIsNotASearch() {
        XCTAssertTrue(DashboardListBuilder.isSearching(query: "動"))
        XCTAssertFalse(DashboardListBuilder.isSearching(query: ""))
        XCTAssertFalse(DashboardListBuilder.isSearching(query: " \n "))
    }

    /// **検索中は状態の絞り込みを外します。**
    /// 候補（`suggestions`）は状態を見ないため、一覧側だけ絞ると
    /// 「候補に出たのに選ぶと見つかりません」になります。
    func testSearchingWidensTheStateFilterToAll() {
        XCTAssertEqual(DashboardListBuilder.effectiveStateFilter(.active, query: "動画"), .all)
        XCTAssertEqual(DashboardListBuilder.effectiveStateFilter(.history, query: "動画"), .all)
    }

    /// 検索していないときは、利用者が選んだ絞り込みをそのまま使います。
    func testTheChosenStateFilterSurvivesWithoutAQuery() {
        XCTAssertEqual(DashboardListBuilder.effectiveStateFilter(.active, query: ""), .active)
        XCTAssertEqual(DashboardListBuilder.effectiveStateFilter(.paused, query: "   "), .paused)
    }

    /// **候補に出たものは一覧にも出ること。** 「利用中」を選んだまま停止中の費目を検索した
    /// ときに、候補には出るのに一覧が空になる食い違いを防ぎます。
    func testSuggestedPausedItemAlsoAppearsInTheList() {
        let paused = makeSubscription(name: "停止中の動画", renewalOn: date(2026, 2, 10))
        paused.state = .paused

        let suggestions = DashboardListBuilder.suggestions(
            subscriptions: [paused],
            loans: [],
            costTypeFilter: .all,
            query: "動画",
            now: Fixture.now,
            calendar: Fixture.calendar
        )
        let items = DashboardListBuilder.items(
            subscriptions: [paused],
            loans: [],
            stateFilter: DashboardListBuilder.effectiveStateFilter(.active, query: "動画"),
            costTypeFilter: .all,
            query: "動画",
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(suggestions.map(\.name), ["停止中の動画"])
        XCTAssertEqual(items.map(\.name), suggestions.map(\.name))
    }

    /// **種別の絞り込みは検索中も効かせます。** ツールバーに出たままなので、
    /// 勝手に外すと画面の表示と結果が食い違います。
    func testSearchingKeepsTheCostTypeFilter() throws {
        let subscription = makeSubscription(name: "ローン契約メモ", renewalOn: date(2026, 2, 10))
        let loan = try makeSynchronizedLoan(name: "自動車ローン")

        let items = DashboardListBuilder.items(
            subscriptions: [subscription],
            loans: [loan],
            stateFilter: DashboardListBuilder.effectiveStateFilter(.active, query: "ローン"),
            costTypeFilter: .only(.loan),
            query: "ローン",
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(items.map(\.name), ["自動車ローン"])
    }

    /// 識別子は種別ごとに接頭辞を付けます。**費目と借入で `clientID` が衝突しても別物として扱う**ためです。
    func testIdentifiersArePrefixedByKind() throws {
        let sharedID = UUID().uuidString
        let subscription = makeSubscription(name: "動画", renewalOn: date(2026, 2, 10))
        subscription.clientID = sharedID
        let loan = try makeSynchronizedLoan(name: "ローン")
        loan.clientID = sharedID

        let items = DashboardListBuilder.items(
            subscriptions: [subscription],
            loans: [loan],
            stateFilter: .all,
            costTypeFilter: .all,
            query: "",
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(Set(items.map(\.id)).count, 2)
    }

    // MARK: - 次の支払い

    /// **借入も「次の支払い」の対象です。** 費目しか見ないと、明日が返済日でも出てきません。
    func testNextDueComparesSubscriptionsAndLoans() throws {
        let subscription = makeSubscription(name: "動画", renewalOn: date(2026, 2, 10))
        let loan = try makeSynchronizedLoan(name: "自動車ローン")

        let next = DashboardListBuilder.nextDue(
            subscriptions: [subscription],
            loans: [loan],
            costTypeFilter: .all,
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        // 借入の1回目は 2026-01-27、費目の更新は 2026-02-10。
        XCTAssertEqual(next?.name, "自動車ローン")
    }

    /// 過ぎた期日は「次」ではありません。
    func testNextDueSkipsPastDates() {
        let past = makeSubscription(name: "先月更新", renewalOn: date(2025, 12, 10))
        let future = makeSubscription(name: "来月更新", renewalOn: date(2026, 2, 10))

        let next = DashboardListBuilder.nextDue(
            subscriptions: [past, future],
            loans: [],
            costTypeFilter: .all,
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(next?.name, "来月更新")
    }

    /// 今日が期日なら「次」に含めます。今日払うものが消えると使えません。
    func testNextDueIncludesToday() {
        let today = makeSubscription(name: "今日更新", renewalOn: date(2026, 1, 15))

        let next = DashboardListBuilder.nextDue(
            subscriptions: [today],
            loans: [],
            costTypeFilter: .all,
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(next?.name, "今日更新")
    }

    /// 停止中の費目と完済した借入は、もう支払いが来ないので対象外です。
    func testNextDueIgnoresPausedAndCompleted() throws {
        let paused = makeSubscription(name: "停止中", renewalOn: date(2026, 1, 20))
        paused.state = .paused
        let closed = try makeSynchronizedLoan(name: "完済ローン")
        for payment in LoanPaymentStore.sortedPayments(on: closed) {
            payment.status = .paid
        }

        let next = DashboardListBuilder.nextDue(
            subscriptions: [paused],
            loans: [closed],
            costTypeFilter: .all,
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertNil(next)
    }

    // MARK: - 検索候補

    /// **候補に借入も出ること。** 費目しか出さないと、打っている最中に「見つからない」と受け取られます。
    func testSuggestionsIncludeLoans() throws {
        let subscription = makeSubscription(name: "ローン契約メモ", renewalOn: date(2026, 2, 10))
        let loan = try makeSynchronizedLoan(name: "自動車ローン")

        let suggestions = DashboardListBuilder.suggestions(
            subscriptions: [subscription],
            loans: [loan],
            costTypeFilter: .all,
            query: "ローン",
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(suggestions.map(\.name), ["自動車ローン", "ローン契約メモ"])
    }

    func testSuggestionsAreEmptyWithoutAQuery() throws {
        let loan = try makeSynchronizedLoan(name: "自動車ローン")

        let suggestions = DashboardListBuilder.suggestions(
            subscriptions: [],
            loans: [loan],
            costTypeFilter: .all,
            query: "   ",
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertTrue(suggestions.isEmpty)
    }

    /// 候補は件数を絞ります。多すぎると検索欄が画面を覆います。
    func testSuggestionsAreLimited() {
        let subscriptions = (1...10).map {
            makeSubscription(name: "動画\($0)", renewalOn: date(2026, 2, $0))
        }

        let suggestions = DashboardListBuilder.suggestions(
            subscriptions: subscriptions,
            loans: [],
            costTypeFilter: .all,
            query: "動画",
            limit: 6,
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(suggestions.count, 6)
    }

    /// **候補には停止中の費目も出します。** 表示状態と関係なく探せるほうが速いためです。
    func testSuggestionsIgnoreTheStateFilter() {
        let paused = makeSubscription(name: "停止中の動画", renewalOn: date(2026, 2, 10))
        paused.state = .paused

        let suggestions = DashboardListBuilder.suggestions(
            subscriptions: [paused],
            loans: [],
            costTypeFilter: .all,
            query: "動画",
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(suggestions.map(\.name), ["停止中の動画"])
    }

    func testSuggestionSubtitleDescribesTheKind() throws {
        let subscription = makeSubscription(name: "動画", renewalOn: date(2026, 2, 10))
        subscription.category = "エンタメ"
        let loan = try makeSynchronizedLoan(name: "自動車ローン")

        let suggestions = DashboardListBuilder.suggestions(
            subscriptions: [subscription],
            loans: [loan],
            costTypeFilter: .all,
            query: "",
            now: Fixture.now,
            calendar: Fixture.calendar
        )
        XCTAssertTrue(suggestions.isEmpty, "空の検索語では候補を出しません。")

        let items = DashboardListBuilder.items(
            subscriptions: [subscription],
            loans: [loan],
            stateFilter: .all,
            costTypeFilter: .all,
            query: "",
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(items.map(\.searchSubtitle), ["元利均等", "エンタメ"])
    }

    // MARK: - 補助

    private func makeSubscription(name: String, renewalOn renewalDate: Date) -> Subscription {
        Subscription(name: name, originalAmount: 1_000, renewalDate: renewalDate)
    }

    private func makeSynchronizedLoan(name: String) throws -> Loan {
        let loan = Loan(
            name: name,
            method: .equalPayment,
            annualRatePercent: 3.0,
            originalPrincipal: 1_000_000,
            borrowedOn: date(2025, 12, 10),
            totalInstallments: 12,
            paymentDay: 27
        )
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        return loan
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Fixture.calendar.date(from: components) ?? .distantPast
    }
}

/// 時間軸に出す「次に出ていく額」です。
final class DashboardListItemNextDueAmountTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateComponents(calendar: calendar, year: year, month: month, day: day).date!
    }

    /// 月払いはその月の額です。
    func testMonthlySubscriptionReportsItsMonthlyAmount() {
        let subscription = Subscription(
            name: "Netflix",
            originalAmount: 1_980,
            renewalDate: date(2026, 8, 28)
        )

        XCTAssertEqual(DashboardListItem.subscription(subscription).nextDueAmount, 1_980)
    }

    /// **年払いは年額をそのまま返します。** 次に出ていくのは1/12ではなく全額だからです。
    func testYearlySubscriptionReportsTheFullYearlyAmount() {
        let subscription = Subscription(
            name: "Adobe CC",
            originalAmount: 28_776,
            billingCycle: .yearly,
            renewalDate: date(2026, 8, 20)
        )

        XCTAssertEqual(DashboardListItem.subscription(subscription).nextDueAmount, 28_776)
    }

    /// 停止中の費目は出ていきません。
    func testPausedSubscriptionHasNoAmount() {
        let subscription = Subscription(
            name: "止めたやつ",
            originalAmount: 1_000,
            state: .paused,
            renewalDate: date(2026, 8, 28)
        )

        XCTAssertNil(DashboardListItem.subscription(subscription).nextDueAmount)
    }
}
