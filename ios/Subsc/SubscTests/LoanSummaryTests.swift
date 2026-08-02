import XCTest
@testable import Subsc

/// 詳細画面と一覧行が使う要約値のテストです。
///
/// **残高・完済予定日・進捗は予定表から導かれる**ため、画面ごとに導き方が違うと表示が食い違います。
/// ここで導き方を1つに固定します。
final class LoanSummaryTests: XCTestCase {
    private enum Fixture {
        static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt
            return calendar
        }
    }

    // MARK: - 予定表を作る前

    func testSummaryBeforeSynchronizeFallsBackToTheContractedPrincipal() {
        let loan = makeLoan()

        let summary = LoanSummary.make(for: loan)

        XCTAssertEqual(summary.startingPrincipal, 1_000_000)
        XCTAssertEqual(summary.currentBalance, 1_000_000)
        XCTAssertNil(summary.nextDueDate)
        XCTAssertNil(summary.completionDate)
        XCTAssertEqual(summary.remainingCount, 0)
        XCTAssertFalse(summary.isCompleted)
        XCTAssertEqual(summary.progress, 0)
    }

    /// 「今の残高から」登録した場合は、当初元本ではなく開始残高が母数になります。
    func testStartingPrincipalFollowsTheRegistrationStyle() {
        let loan = makeLoan()
        loan.origin = .fromCurrentBalance
        loan.startingBalance = 400_000
        loan.startingInstallments = 6

        let summary = LoanSummary.make(for: loan)

        XCTAssertEqual(summary.startingPrincipal, 400_000)
    }

    // MARK: - 予定表を作ったあと

    func testNextPaymentIsTheEarliestScheduledInstallment() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)

        let summary = LoanSummary.make(for: loan)

        XCTAssertEqual(summary.nextDueDate, date(2026, 1, 27))
        XCTAssertEqual(summary.nextAmount, 84_694, accuracy: 0.5)
        XCTAssertEqual(summary.remainingCount, 12)
        XCTAssertEqual(summary.totalCount, 12)
        XCTAssertEqual(summary.completionDate, date(2026, 12, 27))
    }

    /// 返済した回までの残高が現在残高になります。**予定はまだ起きていないので数えません。**
    func testCurrentBalanceFollowsTheLastSettledInstallment() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        try LoanPaymentStore.recordPayment(
            amount: 84_694,
            period: 1,
            on: loan,
            calendar: Fixture.calendar
        )

        let summary = LoanSummary.make(for: loan)
        let first = try XCTUnwrap(LoanPaymentStore.sortedPayments(on: loan).first)

        XCTAssertEqual(summary.currentBalance, first.balanceAfter, accuracy: 0.5)
        XCTAssertLessThan(summary.currentBalance, 1_000_000)
        XCTAssertEqual(summary.remainingCount, 11)
        XCTAssertEqual(summary.nextDueDate, date(2026, 2, 27))
    }

    /// 滞納は残高を減らしません。**利息が繰り入れられて残高は増えます。**
    func testMissedInstallmentIncreasesTheBalanceAndIsCounted() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        try LoanPaymentStore.markMissed(period: 1, on: loan, calendar: Fixture.calendar)

        let summary = LoanSummary.make(for: loan)

        XCTAssertGreaterThan(summary.currentBalance, 1_000_000)
        XCTAssertEqual(summary.missedCount, 1)
        XCTAssertEqual(summary.progress, 0, "元金が減っていないので進捗は0のままです。")
    }

    func testProgressIsTheRepaidShareOfThePrincipal() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        for period in 1...6 {
            let payment = try XCTUnwrap(
                LoanPaymentStore.sortedPayments(on: loan).first { $0.period == period }
            )
            try LoanPaymentStore.recordPayment(
                amount: payment.scheduledAmount,
                period: period,
                on: loan,
                calendar: Fixture.calendar
            )
        }

        let summary = LoanSummary.make(for: loan)

        XCTAssertEqual(summary.repaidPrincipal, 1_000_000 - summary.currentBalance, accuracy: 0.5)
        XCTAssertGreaterThan(summary.progress, 0.4)
        XCTAssertLessThan(summary.progress, 0.6)
    }

    func testAllInstallmentsSettledMeansCompleted() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        for payment in LoanPaymentStore.sortedPayments(on: loan) {
            payment.status = .paid
        }

        let summary = LoanSummary.make(for: loan)

        XCTAssertTrue(summary.isCompleted)
        XCTAssertNil(summary.nextDueDate)
        XCTAssertEqual(summary.remainingCount, 0)
    }

    /// 完済にしたのに端数が残っていても、進捗は1で頭打ちにします。
    func testProgressNeverExceedsOne() {
        let loan = makeLoan()
        loan.isClosed = true

        let summary = LoanSummary.make(for: loan)

        XCTAssertTrue(summary.isCompleted)
        XCTAssertEqual(summary.progress, 1)
    }

    func testTotalInterestSumsEveryInstallment() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)

        let summary = LoanSummary.make(for: loan)
        let expected = LoanPaymentStore.sortedPayments(on: loan)
            .reduce(0) { $0 + $1.interestPortion }

        XCTAssertEqual(summary.totalInterest, expected, accuracy: 0.5)
        XCTAssertGreaterThan(summary.totalInterest, 0)
    }

    // MARK: - 補助

    private func makeLoan() -> Loan {
        Loan(
            name: "自動車ローン",
            method: .equalPayment,
            annualRatePercent: 3.0,
            originalPrincipal: 1_000_000,
            borrowedOn: date(2025, 12, 10),
            totalInstallments: 12,
            paymentDay: 27
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Fixture.calendar.date(from: components) ?? .distantPast
    }
}
