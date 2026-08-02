import XCTest
@testable import Subsc

/// 返済予定表の保存が、**同じ回を1件に保てているか**と、
/// **滞納・繰上返済の記録が予定表へ反映されるか**のテストです。
final class LoanPaymentStoreTests: XCTestCase {
    private enum Fixture {
        static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt
            return calendar
        }
    }

    // MARK: - 予定表の生成

    func testSynchronizeCreatesOnePaymentPerInstallment() throws {
        let loan = makeLoan()

        let result = try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)

        XCTAssertEqual(result.payments.count, 12)
        XCTAssertEqual(result.payments.map(\.period), Array(1...12))
        XCTAssertTrue(result.removed.isEmpty)
    }

    func testEachPaymentCarriesTheScheduledBreakdown() throws {
        let loan = makeLoan()

        let result = try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        let first = try XCTUnwrap(result.payments.first)

        XCTAssertEqual(first.scheduledAmount, 84_694, accuracy: 0.5)
        XCTAssertEqual(first.interestPortion, 1_000_000 * 0.0025, accuracy: 0.5)
        XCTAssertEqual(
            first.principalPortion,
            first.scheduledAmount - first.interestPortion,
            accuracy: 0.5
        )
        XCTAssertEqual(first.status, .scheduled)
    }

    func testDueDatesUseThePaymentDayAndStartTheMonthAfterBorrowing() throws {
        let loan = makeLoan()

        let result = try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        let first = try XCTUnwrap(result.payments.first)

        // 借入日 2025-12-10、返済日27日 → 1回目は 2026-01-27。
        XCTAssertEqual(first.dueOn, date(2026, 1, 27))
        XCTAssertEqual(first.year, 2026)
        XCTAssertEqual(first.month, 1)
    }

    /// **同じ回が2件できないこと。** 一意制約が使えないため、ここで保つしかありません。
    func testSynchronizingTwiceDoesNotDuplicatePayments() throws {
        let loan = makeLoan()

        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        let result = try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)

        XCTAssertEqual(result.payments.count, 12)
        XCTAssertEqual(Set(result.payments.map(\.period)).count, 12)
    }

    // MARK: - 滞納

    func testMarkingAPaymentAsMissedSetsItToZero() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)

        let result = try LoanPaymentStore.markMissed(
            period: 3,
            on: loan,
            calendar: Fixture.calendar
        )
        let missed = try XCTUnwrap(result.payments.first { $0.period == 3 })

        XCTAssertEqual(missed.status, .missed)
        XCTAssertEqual(missed.effectiveAmount, 0)
    }

    /// 滞納すると**完済が後ろへずれます。** 残高が減らないまま利息だけ乗るためです。
    func testMissedPaymentPushesTheScheduleBack() throws {
        let loan = makeLoan()
        let before = try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        let lastBefore = try XCTUnwrap(before.payments.last?.dueOn)

        let after = try LoanPaymentStore.markMissed(
            period: 3,
            on: loan,
            calendar: Fixture.calendar
        )
        let lastAfter = try XCTUnwrap(after.payments.last?.dueOn)

        XCTAssertGreaterThan(after.payments.count, before.payments.count)
        XCTAssertGreaterThan(lastAfter, lastBefore)
    }

    /// **記録は計算より優先されます。** 組み直しても滞納は残らなければなりません。
    func testMissedStatusSurvivesResynchronization() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        try LoanPaymentStore.markMissed(period: 3, on: loan, calendar: Fixture.calendar)

        let result = try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        let missed = try XCTUnwrap(result.payments.first { $0.period == 3 })

        XCTAssertEqual(missed.status, .missed)
    }

    // MARK: - 返済と繰上返済

    func testRecordingTheScheduledAmountMarksItPaid() throws {
        let loan = makeLoan()
        let synchronized = try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        let scheduled = try XCTUnwrap(synchronized.payments.first { $0.period == 1 }).scheduledAmount

        let result = try LoanPaymentStore.recordPayment(
            amount: scheduled,
            period: 1,
            on: loan,
            calendar: Fixture.calendar
        )
        let paid = try XCTUnwrap(result.payments.first { $0.period == 1 })

        XCTAssertEqual(paid.status, .paid)
        XCTAssertEqual(paid.effectiveAmount, scheduled, accuracy: 0.5)
    }

    /// 予定より多く払えば繰上返済。**上乗せは全額元金へ充当され、回数が減ります。**
    func testPayingMoreThanScheduledShortensTheSchedule() throws {
        let loan = makeLoan()
        let before = try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        let scheduled = try XCTUnwrap(before.payments.first { $0.period == 3 }).scheduledAmount

        let after = try LoanPaymentStore.recordPayment(
            amount: scheduled + 200_000,
            period: 3,
            on: loan,
            calendar: Fixture.calendar
        )

        XCTAssertLessThan(after.payments.count, before.payments.count)
        let prepaid = try XCTUnwrap(after.payments.first { $0.period == 3 })
        XCTAssertEqual(prepaid.status, .prepaid)
    }

    /// 予定が短くなって余った回は `removed` へ入り、**呼び出し側が削除できるようになります。**
    func testShortenedScheduleReportsTheLeftoverPaymentsAsRemoved() throws {
        let loan = makeLoan()
        let before = try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        let scheduled = try XCTUnwrap(before.payments.first { $0.period == 3 }).scheduledAmount

        let after = try LoanPaymentStore.recordPayment(
            amount: scheduled + 200_000,
            period: 3,
            on: loan,
            calendar: Fixture.calendar
        )

        XCTAssertFalse(after.removed.isEmpty)
        XCTAssertTrue(after.removed.allSatisfy { $0.loan == nil })
        XCTAssertTrue(after.removed.allSatisfy { row in
            !after.payments.contains { $0.period == row.period }
        })
    }

    // MARK: - 「今の残高から」の登録

    func testStartingFromCurrentBalanceUsesTheTrackingMonth() throws {
        let loan = Loan(
            name: "残高から登録",
            annualRatePercent: 3.0,
            startingBalance: 500_000,
            startingInstallments: 6,
            startedTrackingOn: date(2026, 4, 3),
            paymentDay: 27
        )
        loan.origin = .fromCurrentBalance

        let result = try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        let first = try XCTUnwrap(result.payments.first)

        XCTAssertEqual(result.payments.count, 6)
        XCTAssertEqual(first.dueOn, date(2026, 4, 27))
    }

    // MARK: - 入力が不正なとき

    func testInvalidTermsThrowInsteadOfProducingAnEmptySchedule() {
        let loan = makeLoan()
        loan.originalPrincipal = 0

        XCTAssertThrowsError(try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)) { error in
            XCTAssertEqual(error as? LoanTermsError, .principalMustBePositive)
        }
    }

    // MARK: - 補助

    // MARK: - 記録の取り消し

    /// **滞納は押し間違えます。** 取り消したら完済予定日も元に戻らなければ、記録を直す意味がありません。
    func testClearingAMissedRecordRestoresTheOriginalSchedule() throws {
        let loan = makeLoan()
        let original = try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        let originalCompletion = original.payments.last?.dueOn
        let originalCount = original.payments.count

        try LoanPaymentStore.markMissed(period: 1, on: loan, calendar: Fixture.calendar)
        XCTAssertGreaterThan(LoanPaymentStore.sortedPayments(on: loan).count, originalCount)

        let restored = try LoanPaymentStore.clearRecord(
            period: 1,
            on: loan,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(restored.payments.count, originalCount)
        XCTAssertEqual(restored.payments.last?.dueOn, originalCompletion)
        XCTAssertEqual(restored.payments.first?.status, .scheduled)
    }

    /// 取り消した回の実績は nil へ戻します。0のままだと「実績として0円」と読めてしまいます。
    func testClearingARecordRemovesTheActualAmount() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        try LoanPaymentStore.recordPayment(
            amount: 200_000,
            period: 1,
            on: loan,
            calendar: Fixture.calendar
        )

        try LoanPaymentStore.clearRecord(period: 1, on: loan, calendar: Fixture.calendar)
        let first = try XCTUnwrap(LoanPaymentStore.sortedPayments(on: loan).first)

        XCTAssertNil(first.actualAmount)
        XCTAssertNil(first.recordedAt)
        XCTAssertEqual(first.status, .scheduled)
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
