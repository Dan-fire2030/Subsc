import XCTest
@testable import Subsc

/// 返済日の通知が、**必要な回だけ予約され、応答が正しく読み解かれるか**のテストです。
final class LoanNotificationTests: XCTestCase {
    private let clientID = "11111111-2222-3333-4444-555555555555"

    private enum Fixture {
        static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt
            return calendar
        }
    }

    // MARK: - 予約する対象

    func testUpcomingScheduledPaymentsAreNotified() throws {
        let loan = try makeSynchronizedLoan()

        let planned = LoanNotificationPlanner.plannedPayments(
            loans: [loan],
            now: date(2026, 1, 1),
            limit: 20,
            calendar: Fixture.calendar
        )

        // 3ヶ月先まで＝1月27日・2月27日・3月27日の3件。
        XCTAssertEqual(planned.count, 3)
        // **返済日そのもの（0時）ではなく、通知を出す時刻まで進めた日時になります。**
        // 0時のままだと深夜に鳴ります。
        XCTAssertEqual(
            planned.first?.date,
            Fixture.calendar.date(
                bySettingHour: LoanNotificationPlanner.notificationHour,
                minute: 0,
                second: 0,
                of: date(2026, 1, 27)
            )
        )
    }

    func testNotificationsCarryTheActionCategory() throws {
        let loan = try makeSynchronizedLoan()

        let planned = LoanNotificationPlanner.plannedPayments(
            loans: [loan],
            now: date(2026, 1, 1),
            limit: 20,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(
            planned.first?.categoryIdentifier,
            LoanNotificationAction.categoryIdentifier
        )
    }

    /// 記録が付いた回は計画から外れ、再スケジュール時に取り消されます。
    func testRecordedPaymentsAreNotNotifiedAgain() throws {
        let loan = try makeSynchronizedLoan()
        try LoanPaymentStore.markMissed(period: 1, on: loan, calendar: Fixture.calendar)

        let planned = LoanNotificationPlanner.plannedPayments(
            loans: [loan],
            now: date(2026, 1, 1),
            limit: 20,
            calendar: Fixture.calendar
        )

        XCTAssertFalse(planned.contains { $0.date == self.date(2026, 1, 27) })
    }

    func testClosedLoansAreNotNotified() throws {
        let loan = try makeSynchronizedLoan()
        loan.isClosed = true

        let planned = LoanNotificationPlanner.plannedPayments(
            loans: [loan],
            now: date(2026, 1, 1),
            limit: 20,
            calendar: Fixture.calendar
        )

        XCTAssertTrue(planned.isEmpty)
    }

    /// 停止中は返済日が来ても払わないので、通知しません。
    func testPausedLoansAreNotNotified() throws {
        let loan = try makeSynchronizedLoan()
        try LoanPaymentStore.pause(loan: loan, on: date(2026, 1, 1), calendar: Fixture.calendar)

        let planned = LoanNotificationPlanner.plannedPayments(
            loans: [loan],
            now: date(2026, 1, 1),
            limit: 20,
            calendar: Fixture.calendar
        )

        XCTAssertTrue(planned.isEmpty)
    }

    /// 再開したら予約し直されます。**止めたきり二度と通知が来ないと、返済を忘れます。**
    func testResumedLoansAreNotifiedAgain() throws {
        let loan = try makeSynchronizedLoan()
        try LoanPaymentStore.pause(loan: loan, on: date(2026, 1, 1), calendar: Fixture.calendar)
        try LoanPaymentStore.resume(loan: loan, on: date(2026, 3, 1), calendar: Fixture.calendar)

        let planned = LoanNotificationPlanner.plannedPayments(
            loans: [loan],
            now: date(2026, 3, 1),
            limit: 20,
            calendar: Fixture.calendar
        )

        XCTAssertFalse(planned.isEmpty)
    }

    func testPastDueDatesAreNotNotified() throws {
        let loan = try makeSynchronizedLoan()

        let planned = LoanNotificationPlanner.plannedPayments(
            loans: [loan],
            now: date(2026, 3, 1),
            limit: 20,
            calendar: Fixture.calendar
        )

        XCTAssertFalse(planned.contains { $0.date < self.date(2026, 3, 1) })
    }

    func testTheLimitIsRespected() throws {
        let loan = try makeSynchronizedLoan()

        let planned = LoanNotificationPlanner.plannedPayments(
            loans: [loan],
            now: date(2026, 1, 1),
            limit: 2,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(planned.count, 2)
    }

    // MARK: - 応答の読み解き

    /// **clientID にハイフンが含まれます。** 前から分割すると UUID の途中で切れます。
    func testResponseIsParsedFromAnIdentifierContainingHyphens() throws {
        let identifier = NotificationIdentifier.loanPayment(clientID: clientID, periodKey: 202_603)

        let response = try XCTUnwrap(
            LoanNotificationResponse(identifier: identifier, actionIdentifier: "loan-paid")
        )

        XCTAssertEqual(response, .paid(clientID: clientID, periodKey: 202_603))
    }

    func testMissedActionIsParsed() throws {
        let identifier = NotificationIdentifier.loanPayment(clientID: clientID, periodKey: 202_603)

        let response = try XCTUnwrap(
            LoanNotificationResponse(identifier: identifier, actionIdentifier: "loan-missed")
        )

        XCTAssertEqual(response, .missed(clientID: clientID, periodKey: 202_603))
        XCTAssertEqual(response.clientID, clientID)
        XCTAssertEqual(response.periodKey, 202_603)
    }

    func testOtherNamespacesAreIgnored() {
        let reminder = NotificationIdentifier.reminder(clientID: clientID, periodKey: 202_603)

        XCTAssertNil(
            LoanNotificationResponse(identifier: reminder, actionIdentifier: "loan-paid")
        )
    }

    func testUnknownActionsAreIgnored() {
        let identifier = NotificationIdentifier.loanPayment(clientID: clientID, periodKey: 202_603)

        XCTAssertNil(
            LoanNotificationResponse(identifier: identifier, actionIdentifier: "somethingNew")
        )
    }

    func testMalformedIdentifiersAreIgnored() {
        XCTAssertNil(
            LoanNotificationResponse(identifier: "subsc-loan-", actionIdentifier: "loan-paid")
        )
        XCTAssertNil(
            LoanNotificationResponse(
                identifier: "subsc-loan-\(clientID)-notANumber",
                actionIdentifier: "loan-paid"
            )
        )
    }

    // MARK: - 返済日を過ぎた回

    func testPastDuePaymentsAreTreatedAsPaid() throws {
        let loan = try makeSynchronizedLoan()

        let settled = LoanPaymentStore.settlePastDue(on: loan, now: date(2026, 3, 1))

        XCTAssertEqual(settled.map(\.period), [1, 2])
        XCTAssertTrue(settled.allSatisfy { $0.status == .paid })
        // **実績は入れません。** 「予定どおり」と「実績0円」を区別できる状態を保ちます。
        XCTAssertTrue(settled.allSatisfy { $0.actualAmount == nil })
    }

    func testRecordedPaymentsAreNotOverwrittenBySettling() throws {
        let loan = try makeSynchronizedLoan()
        try LoanPaymentStore.markMissed(period: 1, on: loan, calendar: Fixture.calendar)

        LoanPaymentStore.settlePastDue(on: loan, now: date(2026, 3, 1))
        let first = try XCTUnwrap(
            LoanPaymentStore.sortedPayments(on: loan).first { $0.period == 1 }
        )

        XCTAssertEqual(first.status, .missed)
    }

    // MARK: - 補助

    private func makeSynchronizedLoan() throws -> Loan {
        let loan = Loan(
            clientID: clientID,
            name: "テストローン",
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
