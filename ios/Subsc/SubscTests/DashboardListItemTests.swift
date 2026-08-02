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

    /// 借入に「停止中」はありません。停止中で絞ったら消えるのが正しい挙動です。
    func testLoansNeverAppearUnderThePausedFilter() throws {
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
