import XCTest
@testable import Subsc

/// 返済の一時停止のテストです。
///
/// **滞納との違いを固定するのがこのファイルの主目的**です。滞納はその月の利息が残高へ繰り入れられ、
/// 総利息が増えます。一時停止は利息を発生させず、**期日を後ろへずらすだけ**です（SPEC A-2）。
/// 両者を同じ仕組みで実装すると、この違いが静かに壊れます。
final class LoanPauseTests: XCTestCase {
    private enum Fixture {
        static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt
            return calendar
        }
    }

    // MARK: - 繰り延べ

    /// 3ヶ月止めたら、残りの返済日が**ちょうど3ヶ月**後ろへずれます。
    func testResumingAfterThreeMonthsPushesTheScheduleBackByThreeMonths() throws {
        let loan = makeLoan()
        let before = try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        let completionBefore = try XCTUnwrap(before.payments.last?.dueOn)

        // 1回目（2026-01-27）の直後に停止し、3回ぶんの返済日を跨いでから再開します。
        try LoanPaymentStore.pause(loan: loan, on: date(2026, 2, 1), calendar: Fixture.calendar)
        let after = try LoanPaymentStore.resume(
            loan: loan,
            on: date(2026, 5, 1),
            calendar: Fixture.calendar
        )
        let completionAfter = try XCTUnwrap(after.payments.last?.dueOn)

        XCTAssertEqual(
            completionAfter,
            Fixture.calendar.date(byAdding: .month, value: 3, to: completionBefore)
        )
    }

    /// **停止しても総利息と残高は増えません。** ここが滞納との決定的な違いです。
    func testPausingDoesNotAddInterest() throws {
        let loan = makeLoan()
        let before = try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        let interestBefore = before.payments.reduce(0) { $0 + $1.interestPortion }
        let finalBalanceBefore = try XCTUnwrap(before.payments.last?.balanceAfter)

        try LoanPaymentStore.pause(loan: loan, on: date(2026, 2, 1), calendar: Fixture.calendar)
        let after = try LoanPaymentStore.resume(
            loan: loan,
            on: date(2026, 5, 1),
            calendar: Fixture.calendar
        )
        let interestAfter = after.payments.reduce(0) { $0 + $1.interestPortion }

        XCTAssertEqual(interestAfter, interestBefore, accuracy: 0.5)
        XCTAssertEqual(try XCTUnwrap(after.payments.last?.balanceAfter), finalBalanceBefore, accuracy: 0.5)
    }

    /// 滞納と取り違えていないことを、**総利息が増える側**からも確かめます。
    func testMissingAPaymentStillAddsInterestUnlikePausing() throws {
        let paused = makeLoan()
        try LoanPaymentStore.synchronize(loan: paused, calendar: Fixture.calendar)
        try LoanPaymentStore.pause(loan: paused, on: date(2026, 2, 1), calendar: Fixture.calendar)
        let pausedResult = try LoanPaymentStore.resume(
            loan: paused,
            on: date(2026, 3, 1),
            calendar: Fixture.calendar
        )

        let missed = makeLoan()
        try LoanPaymentStore.synchronize(loan: missed, calendar: Fixture.calendar)
        let missedResult = try LoanPaymentStore.markMissed(
            period: 2,
            on: missed,
            calendar: Fixture.calendar
        )

        let pausedInterest = pausedResult.payments.reduce(0) { $0 + $1.interestPortion }
        let missedInterest = missedResult.payments.reduce(0) { $0 + $1.interestPortion }

        XCTAssertGreaterThan(missedInterest, pausedInterest)
    }

    /// **同じ月のうちに再開したら何もずれません。** 返済日を1度も跨いでいないためです。
    func testResumingWithinTheSameMonthChangesNothing() throws {
        let loan = makeLoan()
        let before = try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        let completionBefore = try XCTUnwrap(before.payments.last?.dueOn)

        try LoanPaymentStore.pause(loan: loan, on: date(2026, 2, 1), calendar: Fixture.calendar)
        let after = try LoanPaymentStore.resume(
            loan: loan,
            on: date(2026, 2, 20),
            calendar: Fixture.calendar
        )

        XCTAssertEqual(after.payments.last?.dueOn, completionBefore)
        XCTAssertFalse(after.payments.contains { $0.status == .deferred })
    }

    /// 繰り延べた返済日が**返済日（31日指定）へ丸め直される**ことを確かめます。
    ///
    /// 前サイクルで踏んだ月末ずれの再発防止です。短い月に丸められた日付を起点に
    /// 月を足すだけだと、以降ずっとその日で固定されます。
    func testDeferredDueDatesAreSnappedBackToThePaymentDay() throws {
        let loan = Loan(
            name: "月末テスト",
            annualRatePercent: 3.0,
            originalPrincipal: 1_000_000,
            borrowedOn: date(2025, 12, 10),
            totalInstallments: 12,
            paymentDay: 31
        )
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)

        // 2月を跨いで再開します。2月は31日が無いため28日へ丸められます。
        try LoanPaymentStore.pause(loan: loan, on: date(2026, 2, 1), calendar: Fixture.calendar)
        let after = try LoanPaymentStore.resume(
            loan: loan,
            on: date(2026, 4, 1),
            calendar: Fixture.calendar
        )

        // 繰り延べ後も、31日のある月では31日に戻っていること。
        let march = try XCTUnwrap(after.payments.first { payment -> Bool in
            payment.year == 2026 && payment.month == 3
        })
        XCTAssertEqual(march.dueOn, date(2026, 3, 31))
    }

    // MARK: - 予定表の自動進行

    /// **停止中は返済が勝手に進みません。** 進むと一時停止が無意味になります。
    func testPastDueInstallmentsAreNotSettledWhilePaused() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        try LoanPaymentStore.pause(loan: loan, on: date(2026, 1, 1), calendar: Fixture.calendar)

        let settled = LoanPaymentStore.settlePastDue(on: loan, now: date(2026, 4, 1))

        XCTAssertTrue(settled.isEmpty)
        XCTAssertFalse(LoanPaymentStore.sortedPayments(on: loan).contains { $0.status == .paid })
    }

    /// 停止していなければ従来どおり進みます（上のテストが常に通る作りになっていないことの確認）。
    func testPastDueInstallmentsAreSettledWhenNotPaused() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)

        let settled = LoanPaymentStore.settlePastDue(on: loan, now: date(2026, 4, 1))

        XCTAssertFalse(settled.isEmpty)
    }

    // MARK: - 状態

    func testPausingRecordsWhenItStarted() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)

        try LoanPaymentStore.pause(loan: loan, on: date(2026, 2, 1), calendar: Fixture.calendar)

        XCTAssertTrue(loan.isPaused)
        XCTAssertEqual(loan.pausedOn, date(2026, 2, 1))
    }

    /// **再開したら両方を同時に消します。** 片方だけ残ると「停止中なのに開始日が無い」状態になります。
    func testResumingClearsBothPauseFields() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        try LoanPaymentStore.pause(loan: loan, on: date(2026, 2, 1), calendar: Fixture.calendar)

        try LoanPaymentStore.resume(loan: loan, on: date(2026, 5, 1), calendar: Fixture.calendar)

        XCTAssertFalse(loan.isPaused)
        XCTAssertNil(loan.pausedOn)
    }

    /// **完済したローンは停止できません。** 止める返済が残っていないためです。
    func testClosedLoanCannotBePaused() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        for payment in LoanPaymentStore.sortedPayments(on: loan) {
            payment.status = .paid
        }
        LoanPaymentStore.settlePastDue(on: loan, now: date(2027, 12, 31))
        XCTAssertTrue(loan.isClosed)

        XCTAssertThrowsError(
            try LoanPaymentStore.pause(loan: loan, on: date(2026, 2, 1), calendar: Fixture.calendar)
        )
        XCTAssertFalse(loan.isPaused)
    }

    /// 停止中の回は**レポートへ0円で計上されます**（滞納と同じ扱い）。
    func testDeferredInstallmentsCountAsZero() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        try LoanPaymentStore.pause(loan: loan, on: date(2026, 2, 1), calendar: Fixture.calendar)
        let after = try LoanPaymentStore.resume(
            loan: loan,
            on: date(2026, 4, 1),
            calendar: Fixture.calendar
        )

        let deferred = after.payments.filter { $0.status == .deferred }
        XCTAssertFalse(deferred.isEmpty)
        for payment in deferred {
            XCTAssertEqual(payment.effectiveAmount, 0)
            XCTAssertEqual(payment.interestPortion, 0)
            XCTAssertEqual(payment.principalPortion, 0)
        }
    }

    /// **記録は計算より優先されます。** 組み直しても繰り延べは残らなければなりません。
    func testDeferredStatusSurvivesResynchronization() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        try LoanPaymentStore.pause(loan: loan, on: date(2026, 2, 1), calendar: Fixture.calendar)
        let after = try LoanPaymentStore.resume(
            loan: loan,
            on: date(2026, 4, 1),
            calendar: Fixture.calendar
        )
        let deferredPeriods = Set(after.payments.filter { $0.status == .deferred }.map(\.period))

        let again = try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        let stillDeferred = Set(again.payments.filter { $0.status == .deferred }.map(\.period))

        XCTAssertEqual(stillDeferred, deferredPeriods)
    }

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
