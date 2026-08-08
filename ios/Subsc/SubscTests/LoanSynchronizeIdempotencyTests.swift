import XCTest
@testable import Subsc

/// 予定表の組み直しが**何も変わらないときは何も書かない**ことを固定します。
///
/// **これが崩れるとアプリが無限に回ります（2026-08-08に実際に起きました）。**
/// `RootView` は `.task(id:)` の鍵に `Loan.updatedAt` を含めており、
/// そのタスクの中で `synchronize` が呼ばれます。組み直すたびに `updatedAt` を
/// 書くと、鍵が変わってタスクが再発火し、また書く、という循環になります。
/// 実測では起動後わずかな時間に `reconcile` が501回走り、CPUが100%に張り付きました。
///
/// **書き込みを減らす話ではなく、正しさの話です。** `updatedAt` は「変わった」という
/// 意味を持つ値なので、変わっていないのに進めてはいけません。CloudKitへ無意味な
/// 同期を流し続ける原因にもなります。
final class LoanSynchronizeIdempotencyTests: XCTestCase {
    private enum Fixture {
        static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt
            return calendar
        }

        /// 「書かれたら必ず分かる」ようにするための目印です。
        /// `.now` どうしの比較は解像度に頼ることになるため使いません。
        static let marker = Date(timeIntervalSince1970: 0)
    }

    // MARK: - 組み直し

    /// 予定表を初めて作るときは、実際に増えるので `updatedAt` が進みます。
    func testFirstSynchronizeMarksTheLoanAsUpdated() throws {
        let loan = makeLoan()
        loan.updatedAt = Fixture.marker

        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)

        XCTAssertGreaterThan(loan.updatedAt, Fixture.marker)
        XCTAssertFalse(LoanPaymentStore.sortedPayments(on: loan).isEmpty)
    }

    /// **同じ条件で組み直しても2回目は何も書きません。** ここが無限ループの分かれ目です。
    func testSecondSynchronizeDoesNotTouchUpdatedAt() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        let periodsBefore = LoanPaymentStore.sortedPayments(on: loan).map(\.period)

        loan.updatedAt = Fixture.marker
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)

        XCTAssertEqual(loan.updatedAt, Fixture.marker)
        // 書かないだけで、予定表そのものは同じ内容が保たれています。
        XCTAssertEqual(LoanPaymentStore.sortedPayments(on: loan).map(\.period), periodsBefore)
    }

    /// 条件が変われば当然書きます。**書かなくなること自体が目的ではありません。**
    func testSynchronizeMarksUpdatedWhenTheScheduleActuallyChanges() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)

        loan.updatedAt = Fixture.marker
        loan.totalInstallments += 6
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)

        XCTAssertGreaterThan(loan.updatedAt, Fixture.marker)
    }

    /// 回数を減らして予定が短くなったときも、削除が起きているので書きます。
    func testSynchronizeMarksUpdatedWhenPaymentsAreRemoved() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)

        loan.updatedAt = Fixture.marker
        loan.totalInstallments -= 4
        let result = try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)

        XCTAssertFalse(result.removed.isEmpty)
        XCTAssertGreaterThan(loan.updatedAt, Fixture.marker)
    }

    // MARK: - 停止中の借入（実際に起きた経路）

    /// **停止中の借入で起動のたびに呼ばれても、2回目以降は何も書きません。**
    ///
    /// `RootView.reconcileSubscriptions` は停止中の借入に対して毎回 `deferPastDue` を
    /// 通します。ここで書き続けたことが、CPU100%の直接の原因でした。
    func testRepeatedDeferOnPausedLoanDoesNotTouchUpdatedAt() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        try LoanPaymentStore.pause(loan: loan, on: date(2026, 2, 1), calendar: Fixture.calendar)

        let now = date(2026, 5, 1)
        try LoanPaymentStore.deferPastDue(on: loan, now: now, calendar: Fixture.calendar)

        loan.updatedAt = Fixture.marker
        try LoanPaymentStore.deferPastDue(on: loan, now: now, calendar: Fixture.calendar)

        XCTAssertEqual(loan.updatedAt, Fixture.marker, "停止中の借入で起動のたびに書き込みが起きています")
    }

    /// 停止していない借入も同じです。こちらは `settlePastDue` を通ります。
    func testRepeatedSettleOnActiveLoanDoesNotTouchUpdatedAt() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)

        let now = date(2026, 5, 1)
        LoanPaymentStore.settlePastDue(on: loan, now: now)

        loan.updatedAt = Fixture.marker
        LoanPaymentStore.settlePastDue(on: loan, now: now)

        XCTAssertEqual(loan.updatedAt, Fixture.marker)
    }

    // MARK: - 補助

    private func makeLoan() -> Loan {
        Loan(
            name: "テストローン",
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
