import XCTest
@testable import Subsc

/// 年払いは「年に1回の支払い」です。更新月にだけ全額が立ち、他の月には立ちません。
///
/// **1/12ずつ毎月へならしません。** ならすと画面の合計が実際に払う額と合わず、
/// 「今月いくら出ていくか」を見る用途に使えなくなります。
final class YearlyBillingTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func makeYearly(
        amount: Double = 12_000,
        renewalMonth: Int,
        startDate: Date? = nil
    ) -> Subscription {
        let renewalDate = calendar.date(
            from: DateComponents(year: 2026, month: renewalMonth, day: 10)
        )!
        return Subscription(
            name: "年払い",
            originalAmount: amount,
            billingCycle: .yearly,
            renewalDate: renewalDate,
            startDate: startDate
        )
    }

    // MARK: - 費目そのものの解決

    func testFullAmountIsChargedInTheRenewalMonth() {
        let subscription = makeYearly(renewalMonth: 7)

        XCTAssertEqual(subscription.monthlyAmount(forPeriodKey: 202607).amount, 12_000)
    }

    func testNothingIsChargedInOtherMonths() {
        let subscription = makeYearly(renewalMonth: 7)

        XCTAssertEqual(subscription.monthlyAmount(forPeriodKey: 202608).amount, 0)
        XCTAssertEqual(subscription.monthlyAmount(forPeriodKey: 202612).amount, 0)
    }

    /// 更新日は次回ぶんへ繰り越されていきます。**何年ぶんずれていても月は変わりません。**
    func testTheChargeRepeatsInTheSameMonthEveryYear() {
        let subscription = makeYearly(renewalMonth: 3)

        XCTAssertEqual(subscription.monthlyAmount(forPeriodKey: 202503).amount, 12_000)
        XCTAssertEqual(subscription.monthlyAmount(forPeriodKey: 202703).amount, 12_000)
        XCTAssertEqual(subscription.monthlyAmount(forPeriodKey: 202704).amount, 0)
    }

    func testMonthlyPlansAreUnaffected() {
        let subscription = Subscription(
            name: "月払い",
            originalAmount: 1_500,
            billingCycle: .monthly,
            renewalDate: calendar.date(from: DateComponents(year: 2026, month: 7, day: 10))!
        )

        XCTAssertEqual(subscription.monthlyAmount(forPeriodKey: 202607).amount, 1_500)
        XCTAssertEqual(subscription.monthlyAmount(forPeriodKey: 202608).amount, 1_500)
    }

    /// 変動費は月ごとの実績そのものを使うため、支払い周期の影響を受けません。
    func testVariableAmountsStillUseTheirMonthlyRecord() {
        let subscription = Subscription(
            name: "変動費",
            hasVariableAmount: true,
            originalAmount: 0,
            billingCycle: .yearly,
            renewalDate: calendar.date(from: DateComponents(year: 2026, month: 7, day: 10))!
        )
        subscription.amountEntries = [AmountEntry(year: 2026, month: 8, amount: 8_200)]

        XCTAssertEqual(subscription.monthlyAmount(forPeriodKey: 202608).amount, 8_200)
    }

    // MARK: - レポート

    func testMonthlyReportShowsTheWholeAmountOnlyInTheRenewalMonth() {
        let subscription = makeYearly(renewalMonth: 7)
        let july = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let august = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!

        let julyReport = ReportCalculator.report(
            subscriptions: [subscription],
            period: .month,
            cursor: july,
            calendar: calendar
        )
        let augustReport = ReportCalculator.report(
            subscriptions: [subscription],
            period: .month,
            cursor: august,
            calendar: calendar
        )

        XCTAssertEqual(julyReport.total, 12_000, accuracy: 0.001)
        XCTAssertEqual(augustReport.total, 0, accuracy: 0.001)
    }

    /// 年間換算は月ごとの解決を足し上げるため、**年額がちょうど1回ぶん**入ります。
    func testAnnualReportCountsTheChargeExactlyOnce() {
        let subscription = makeYearly(renewalMonth: 7)
        let cursor = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!

        let report = ReportCalculator.report(
            subscriptions: [subscription],
            period: .year,
            cursor: cursor,
            calendar: calendar
        )

        XCTAssertEqual(report.total, 12_000, accuracy: 0.001)
    }

    /// 更新月より後に契約を始めた年は、その年にまだ払っていません。
    func testTheYearOfSigningDoesNotChargeBeforeTheRenewalMonth() {
        let startDate = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let subscription = makeYearly(renewalMonth: 3, startDate: startDate)
        let cursor = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!

        let report = ReportCalculator.report(
            subscriptions: [subscription],
            period: .year,
            cursor: cursor,
            calendar: calendar
        )

        XCTAssertEqual(report.total, 0, accuracy: 0.001)
    }
}
