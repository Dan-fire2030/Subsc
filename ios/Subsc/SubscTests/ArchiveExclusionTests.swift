import XCTest
@testable import Subsc

/// **アーカイブしたものが、一覧・レポート・カレンダーのすべてから消える**ことを縛ります。
///
/// 除外の判断は `DashboardListBuilder` と `ReportCalculator.includes` の入口だけに置いています。
/// 画面ごとに写すと、どこか1つが漏れて「消したはずのものが数字に効く」状態になります。
final class ArchiveExclusionTests: XCTestCase {
    private enum Fixture {
        static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt
            return calendar
        }

        static let now = DateComponents(
            calendar: calendar,
            year: 2026,
            month: 8,
            day: 11
        ).date ?? .distantPast
    }

    // MARK: - 一覧

    /// アーカイブ中は「すべて」にも出ません。**退けた意味がなくなるため**です。
    func testArchivedIsHiddenFromEveryOrdinaryFilter() {
        let archived = makeSubscription(name: "退けたもの", archivedAt: Fixture.now)
        let normal = makeSubscription(name: "ふつうのもの", archivedAt: nil)

        for filter in [SubscriptionFilter.all, .active, .paused, .history] {
            let names = items(subscriptions: [archived, normal], filter: filter).map(\.name)
            XCTAssertFalse(names.contains("退けたもの"), "\(filter.rawValue)にアーカイブが出ています")
        }
    }

    /// 「アーカイブ」の段には、アーカイブ中だけが出ます。
    func testArchivedFilterShowsOnlyArchived() {
        let archived = makeSubscription(name: "退けたもの", archivedAt: Fixture.now)
        let normal = makeSubscription(name: "ふつうのもの", archivedAt: nil)

        let names = items(subscriptions: [archived, normal], filter: .archived).map(\.name)

        XCTAssertEqual(names, ["退けたもの"])
    }

    /// 借入も同じ規則です。
    func testArchivedLoanFollowsTheSameRule() throws {
        let loan = try makeSynchronizedLoan(name: "退けたローン")
        loan.archivedAt = Fixture.now

        XCTAssertTrue(items(loans: [loan], filter: .all).isEmpty)
        XCTAssertEqual(items(loans: [loan], filter: .archived).map(\.name), ["退けたローン"])
    }

    /// **検索候補にも出ません。** 候補に出ると、選んでも一覧に無いことになります。
    func testArchivedIsHiddenFromSearchSuggestions() {
        let archived = makeSubscription(name: "動画配信", archivedAt: Fixture.now)

        let suggestions = DashboardListBuilder.suggestions(
            subscriptions: [archived],
            loans: [],
            costTypeFilter: .all,
            query: "動画",
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertTrue(suggestions.isEmpty)
    }

    // MARK: - レポートとカレンダー

    /// **過ぎ去った月からも外れます。** 停止中と違い、アーカイブは残しません。
    func testArchivedIsExcludedEvenFromPastPeriods() {
        let subscription = makeSubscription(name: "退けたもの", archivedAt: Fixture.now)
        let past = date(2026, 5, 1)

        XCTAssertFalse(
            ReportCalculator.includes(
                subscription,
                period: .month,
                cursor: past,
                now: Fixture.now,
                calendar: Fixture.calendar
            )
        )
    }

    /// アーカイブしていなければ、従来どおり計上されます（除外が効きすぎていないこと）。
    func testNotArchivedIsStillIncluded() {
        let subscription = makeSubscription(name: "ふつうのもの", archivedAt: nil)

        XCTAssertTrue(
            ReportCalculator.includes(
                subscription,
                period: .month,
                cursor: Fixture.now,
                now: Fixture.now,
                calendar: Fixture.calendar
            )
        )
    }

    /// 借入も過ぎ去った月から外れます。
    func testArchivedLoanIsExcludedFromPastPeriods() throws {
        let loan = try makeSynchronizedLoan(name: "退けたローン")
        loan.archivedAt = Fixture.now

        XCTAssertFalse(
            ReportCalculator.includes(
                loan,
                period: .month,
                cursor: date(2026, 5, 1),
                now: Fixture.now,
                calendar: Fixture.calendar
            )
        )
    }

    // MARK: - 復元

    /// **復元すると元の状態へ戻ります。** 停止中だったものは停止中のまま戻ります。
    /// アーカイブは状態を書き換えないため、`archivedAt` を消すだけで元へ戻ります。
    func testRestoringKeepsTheOriginalState() {
        let subscription = makeSubscription(name: "止めていたもの", archivedAt: Fixture.now)
        subscription.state = .paused

        subscription.archivedAt = nil

        XCTAssertEqual(subscription.state, .paused)
        XCTAssertEqual(items(subscriptions: [subscription], filter: .paused).map(\.name), ["止めていたもの"])
    }

    /// **アーカイブしても借入の返済予定表は消えません。** 消すと復元できなくなります。
    func testArchivingALoanKeepsItsPaymentSchedule() throws {
        let loan = try makeSynchronizedLoan(name: "ローン")
        let before = LoanPaymentStore.sortedPayments(on: loan).count
        XCTAssertGreaterThan(before, 0)

        loan.archivedAt = Fixture.now

        XCTAssertEqual(LoanPaymentStore.sortedPayments(on: loan).count, before)
    }

    // MARK: - 材料

    private func items(
        subscriptions: [Subscription] = [],
        loans: [Loan] = [],
        filter: SubscriptionFilter
    ) -> [DashboardListItem] {
        DashboardListBuilder.items(
            subscriptions: subscriptions,
            loans: loans,
            stateFilter: filter,
            costTypeFilter: .all,
            query: "",
            now: Fixture.now,
            calendar: Fixture.calendar
        )
    }

    private func makeSubscription(name: String, archivedAt: Date?) -> Subscription {
        let subscription = Subscription(
            name: name,
            originalAmount: 1_000,
            renewalDate: date(2026, 8, 28)
        )
        subscription.archivedAt = archivedAt
        return subscription
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
        DateComponents(calendar: Fixture.calendar, year: year, month: month, day: day).date
            ?? .distantPast
    }
}
