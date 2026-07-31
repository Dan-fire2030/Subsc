import XCTest
@testable import Subsc

/// 変動費の「その月いくらか」を決めるロジックのテストです。
///
/// 決め方はSPEC R3の3段階：その月の実績 → その月より前で最も新しい実績（見込み）→ 0円。
final class MonthlyAmountResolverTests: XCTestCase {
    private func entries(_ periods: [(Int, Int, Double)]) -> [AmountEntry] {
        periods.map { AmountEntry(year: $0.0, month: $0.1, amount: $0.2) }
    }

    func testTheRecordForThatMonthWins() {
        let resolved = MonthlyAmountResolver.resolve(
            entries: entries([(2026, 6, 6500), (2026, 7, 8200)]),
            periodKey: 202607
        )

        XCTAssertEqual(resolved.amount, 8200)
        XCTAssertEqual(resolved.source, .recorded)
    }

    func testTheMostRecentEarlierRecordIsUsedWhenTheMonthIsMissing() {
        let resolved = MonthlyAmountResolver.resolve(
            entries: entries([(2026, 4, 5000), (2026, 6, 6500)]),
            periodKey: 202607
        )

        XCTAssertEqual(resolved.amount, 6500)
        XCTAssertEqual(resolved.source, .estimated)
    }

    func testTheMostRecentEarlierRecordCanBeInAPreviousYear() {
        let resolved = MonthlyAmountResolver.resolve(
            entries: entries([(2026, 12, 9000)]),
            periodKey: 202702
        )

        XCTAssertEqual(resolved.amount, 9000)
        XCTAssertEqual(resolved.source, .estimated)
    }

    func testLaterRecordsAreNotUsedToFillAnEarlierMonth() {
        // 記録を始める前の月まで遡って見込むと、払っていない額が計上されてしまう
        let resolved = MonthlyAmountResolver.resolve(
            entries: entries([(2026, 7, 8200)]),
            periodKey: 202605
        )

        XCTAssertEqual(resolved.amount, 0)
        XCTAssertEqual(resolved.source, .unavailable)
    }

    func testNoRecordsAtAllResolvesToZero() {
        let resolved = MonthlyAmountResolver.resolve(entries: [], periodKey: 202607)

        XCTAssertEqual(resolved.amount, 0)
        XCTAssertEqual(resolved.source, .unavailable)
    }
}

/// 費目そのものが「その月いくらか」を答えるときの振る舞いです。
final class SubscriptionMonthlyAmountTests: XCTestCase {
    private func makeSubscription(variable: Bool, amount: Double = 0) -> Subscription {
        let subscription = Subscription(
            name: "テスト",
            hasVariableAmount: variable,
            originalAmount: amount,
            renewalDate: .now
        )
        return subscription
    }

    func testFixedAmountIgnoresRecordsAndAlwaysCountsAsRecorded() {
        let subscription = makeSubscription(variable: false, amount: 1490)
        subscription.amountEntries = [AmountEntry(year: 2026, month: 7, amount: 99999)]

        let resolved = subscription.monthlyAmount(forPeriodKey: 202607)

        XCTAssertEqual(resolved.amount, 1490)
        XCTAssertEqual(resolved.source, .recorded)
    }

    func testYearlyFixedAmountIsStillSpreadAcrossMonths() {
        let subscription = makeSubscription(variable: false, amount: 12000)
        subscription.billingCycle = .yearly

        XCTAssertEqual(subscription.monthlyAmount(forPeriodKey: 202607).amount, 1000)
    }

    func testVariableAmountUsesTheRecordForThatMonth() {
        let subscription = makeSubscription(variable: true)
        subscription.amountEntries = [
            AmountEntry(year: 2026, month: 6, amount: 6500),
            AmountEntry(year: 2026, month: 7, amount: 8200)
        ]

        XCTAssertEqual(subscription.monthlyAmount(forPeriodKey: 202607).amount, 8200)
        XCTAssertEqual(subscription.monthlyAmount(forPeriodKey: 202606).amount, 6500)
    }

    func testVariableAmountIsNotDividedByTheBillingCycle() {
        // 月ごとの実績はその月に払った額そのものなので、年払い設定でも12で割らない
        let subscription = makeSubscription(variable: true)
        subscription.billingCycle = .yearly
        subscription.amountEntries = [AmountEntry(year: 2026, month: 7, amount: 8200)]

        XCTAssertEqual(subscription.monthlyAmount(forPeriodKey: 202607).amount, 8200)
    }

    func testVariableAmountInDollarsIsConvertedWithTheStoredRate() {
        let subscription = makeSubscription(variable: true)
        subscription.currency = .usd
        subscription.exchangeRate = 150
        subscription.amountEntries = [AmountEntry(year: 2026, month: 7, amount: 20)]

        XCTAssertEqual(subscription.monthlyAmount(forPeriodKey: 202607).amount, 3000)
    }

    func testVariableAmountWithoutAnyRecordIsZero() {
        let subscription = makeSubscription(variable: true, amount: 5000)

        let resolved = subscription.monthlyAmount(forPeriodKey: 202607)

        // 定額の金額欄に値が残っていても、変動費なら実績が無い限り計上しない
        XCTAssertEqual(resolved.amount, 0)
        XCTAssertEqual(resolved.source, .unavailable)
    }
}
