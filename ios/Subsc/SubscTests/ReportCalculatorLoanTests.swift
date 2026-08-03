import XCTest
@testable import Subsc

/// 借入の返済額がレポートへ入ることのテストです。
///
/// **返済額は見込みにしません**（SPEC 7節）。予定表から確定的に決まるためで、
/// 変動費と同じ「見込み」の扱いにすると、確定している数字が薄く表示されてしまいます。
final class ReportCalculatorLoanTests: XCTestCase {
    private enum Fixture {
        static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt
            return calendar
        }
    }

    // MARK: - 月間

    func testMonthlyReportIncludesTheRepayment() throws {
        let loan = try makeSynchronizedLoan()

        let report = ReportCalculator.report(
            subscriptions: [],
            loans: [loan],
            period: .month,
            cursor: date(2026, 1, 15),
            calendar: Fixture.calendar
        )
        let entry = try XCTUnwrap(report.entries.first)

        XCTAssertEqual(report.entries.count, 1)
        XCTAssertEqual(entry.name, "自動車ローン")
        XCTAssertEqual(entry.amount, 84_694, accuracy: 0.5)
        XCTAssertEqual(entry.costType, .loan)
        XCTAssertEqual(entry.colorHex, CostType.loan.colorHex)
        XCTAssertFalse(entry.isEstimated, "返済額は確定しているので見込み扱いにしません。")
    }

    /// 返済のない月には出てきません。完済後の月にゼロ円の行が並ぶのを避けます。
    func testMonthWithoutARepaymentHasNoEntry() throws {
        let loan = try makeSynchronizedLoan()

        let report = ReportCalculator.report(
            subscriptions: [],
            loans: [loan],
            period: .month,
            cursor: date(2028, 5, 15),
            calendar: Fixture.calendar
        )

        XCTAssertTrue(report.entries.isEmpty)
        XCTAssertEqual(report.total, 0)
    }

    /// **滞納した月の返済額は0です。** 払っていない額を集計に載せると、支出が実態より多く見えます。
    func testMissedMonthIsNotCounted() throws {
        let loan = try makeSynchronizedLoan()
        try LoanPaymentStore.markMissed(period: 1, on: loan, calendar: Fixture.calendar)

        let report = ReportCalculator.report(
            subscriptions: [],
            loans: [loan],
            period: .month,
            cursor: date(2026, 1, 15),
            calendar: Fixture.calendar
        )

        XCTAssertTrue(report.entries.isEmpty)
    }

    /// 繰上返済した月は、予定額ではなく実際に払った額で計上されます。
    func testPrepaidMonthUsesTheActualAmount() throws {
        let loan = try makeSynchronizedLoan()
        try LoanPaymentStore.recordPayment(
            amount: 300_000,
            period: 1,
            on: loan,
            calendar: Fixture.calendar
        )

        let report = ReportCalculator.report(
            subscriptions: [],
            loans: [loan],
            period: .month,
            cursor: date(2026, 1, 15),
            calendar: Fixture.calendar
        )
        let entry = try XCTUnwrap(report.entries.first)

        XCTAssertEqual(entry.amount, 300_000, accuracy: 0.5)
    }

    // MARK: - 年間

    func testAnnualReportSumsEveryRepaymentInTheYear() throws {
        let loan = try makeSynchronizedLoan()
        let expected = LoanPaymentStore.sortedPayments(on: loan)
            .filter { $0.year == 2026 }
            .reduce(0) { $0 + $1.effectiveAmount }

        let report = ReportCalculator.report(
            subscriptions: [],
            loans: [loan],
            period: .year,
            cursor: date(2026, 6, 15),
            calendar: Fixture.calendar
        )
        let entry = try XCTUnwrap(report.entries.first)

        XCTAssertEqual(entry.amount, expected, accuracy: 0.5)
        XCTAssertGreaterThan(entry.amount, 84_694 * 11)
    }

    // MARK: - 費目との共存

    func testLoansAndSubscriptionsAreCombinedAndSortedByAmount() throws {
        let loan = try makeSynchronizedLoan()
        let subscription = Subscription(
            name: "動画",
            originalAmount: 1_490,
            renewalDate: date(2026, 1, 20)
        )

        let report = ReportCalculator.report(
            subscriptions: [subscription],
            loans: [loan],
            period: .month,
            cursor: date(2026, 1, 15),
            calendar: Fixture.calendar
        )

        XCTAssertEqual(report.entries.map(\.name), ["自動車ローン", "動画"])
        XCTAssertEqual(report.total, 84_694 + 1_490, accuracy: 0.5)
    }

    /// 借入を渡さない既存の呼び出しは、これまでどおり費目だけを集計します。
    func testReportWithoutLoansStaysUnchanged() {
        let subscription = Subscription(
            name: "動画",
            originalAmount: 1_490,
            renewalDate: date(2026, 1, 20)
        )

        let report = ReportCalculator.report(
            subscriptions: [subscription],
            period: .month,
            cursor: date(2026, 1, 15),
            calendar: Fixture.calendar
        )

        XCTAssertEqual(report.entries.count, 1)
        XCTAssertEqual(report.total, 1_490, accuracy: 0.5)
    }

    /// 種別の内訳にも借入が現れ、種別の色が付きます。グラフ4種はこの内訳を共有しています。
    func testCostTypeBreakdownIncludesLoans() throws {
        let loan = try makeSynchronizedLoan()

        let report = ReportCalculator.report(
            subscriptions: [],
            loans: [loan],
            period: .year,
            cursor: date(2026, 6, 15),
            calendar: Fixture.calendar
        )
        let slices = CostTypeBreakdown.slices(from: report.entries)
        let slice = try XCTUnwrap(slices.first)

        XCTAssertEqual(slice.costType, .loan)
        XCTAssertFalse(slice.isEstimated)
    }

    // MARK: - 一時停止

    /// 停止中の借入は、**これからの期間**の集計から外れます。
    func testPausedLoanIsExcludedFromTheCurrentPeriod() throws {
        let loan = try makeSynchronizedLoan()
        try LoanPaymentStore.pause(loan: loan, on: date(2026, 1, 5), calendar: Fixture.calendar)

        let report = ReportCalculator.report(
            subscriptions: [],
            loans: [loan],
            period: .month,
            cursor: date(2026, 1, 15),
            now: date(2026, 1, 15),
            calendar: Fixture.calendar
        )

        XCTAssertTrue(report.entries.isEmpty)
    }

    /// **停止しても、過ぎ去った期間の実績は残ります。**
    ///
    /// 前サイクルで費目側に同じ不具合があり（Codexレビュー Medium 6）、
    /// 停止した瞬間に過去の月の合計まで変わってしまいました。同じ穴を借入で繰り返しません。
    func testPausedLoanStillCountsInPastPeriods() throws {
        let loan = try makeSynchronizedLoan()
        try LoanPaymentStore.pause(loan: loan, on: date(2026, 5, 5), calendar: Fixture.calendar)

        let report = ReportCalculator.report(
            subscriptions: [],
            loans: [loan],
            period: .month,
            cursor: date(2026, 1, 15),
            now: date(2026, 5, 5),
            calendar: Fixture.calendar
        )
        let entry = try XCTUnwrap(report.entries.first)

        XCTAssertEqual(entry.amount, 84_694, accuracy: 0.5)
    }

    // MARK: - 補助

    private func makeSynchronizedLoan() throws -> Loan {
        let loan = Loan(
            name: "自動車ローン",
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
