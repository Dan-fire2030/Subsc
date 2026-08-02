import XCTest
@testable import Subsc

/// 返済日の日付づくりのテストです。
///
/// **`Calendar.date(from:)` は存在しない日付を翌月へ送ります**（2026年2月31日 → 3月3日）。
/// そのまま使うと、返済日を31日にした契約の日付が3日へずれ、以降ずっとそのままになります。
/// 短い月は末日へ丸めることをここで縛ります。
final class LoanDueDateTests: XCTestCase {
    private enum Fixture {
        static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt
            return calendar
        }
    }

    // MARK: - 月末への丸め

    func testDayIsClampedToTheEndOfAShortMonth() {
        let february = date(2026, 2, 10)

        let dueDate = Fixture.calendar.dueDate(inMonthOf: february, day: 31)

        XCTAssertEqual(dueDate, date(2026, 2, 28), "翌月へ送られています。")
    }

    func testLeapYearFebruaryKeepsTheTwentyNinth() {
        let february = date(2028, 2, 10)

        let dueDate = Fixture.calendar.dueDate(inMonthOf: february, day: 31)

        XCTAssertEqual(dueDate, date(2028, 2, 29))
    }

    func testLongMonthKeepsTheRequestedDay() {
        let january = date(2026, 1, 10)

        let dueDate = Fixture.calendar.dueDate(inMonthOf: january, day: 31)

        XCTAssertEqual(dueDate, date(2026, 1, 31))
    }

    // MARK: - 予定表全体

    /// **短い月を起点にしても、長い月では元の日へ戻ること。**
    /// 起点の丸めをそのまま引きずると、以降ずっと28日に固定されてしまいます。
    func testScheduleReturnsToTheRequestedDayInLongMonths() throws {
        let loan = Loan(
            name: "月末ローン",
            annualRatePercent: 3.0,
            originalPrincipal: 1_000_000,
            // 借入日が1月なので、1回目の返済は2月になります。
            borrowedOn: date(2026, 1, 10),
            totalInstallments: 6,
            paymentDay: 31
        )

        let result = try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        let dueDates = result.payments.compactMap(\.dueOn)

        XCTAssertEqual(
            dueDates,
            [
                date(2026, 2, 28),
                date(2026, 3, 31),
                date(2026, 4, 30),
                date(2026, 5, 31),
                date(2026, 6, 30),
                date(2026, 7, 31)
            ]
        )
    }

    /// 返済日が月末に依存しない契約は、これまでどおりの日付になります。
    func testOrdinaryPaymentDayIsUnchanged() throws {
        let loan = Loan(
            name: "通常ローン",
            annualRatePercent: 3.0,
            originalPrincipal: 1_000_000,
            borrowedOn: date(2025, 12, 10),
            totalInstallments: 3,
            paymentDay: 27
        )

        let result = try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)

        XCTAssertEqual(
            result.payments.compactMap(\.dueOn),
            [date(2026, 1, 27), date(2026, 2, 27), date(2026, 3, 27)]
        )
    }

    // MARK: - 端数で回数が増えないこと

    /// **毎月の返済額は円未満を丸めるため、端数が必ず残ります。**
    ///
    /// 残高だけで最終回を判断すると、切り捨てられたぶんが最後に数円残り、
    /// 契約より1回多い返済が生まれます（3回払いのはずが4回目に1円）。
    func testScheduleEndsExactlyAtTheContractedCount() throws {
        for count in [3, 6, 12, 24, 35, 60] {
            let terms = LoanTerms(
                principal: 1_000_000,
                annualRatePercent: 3.0,
                installmentCount: count,
                method: .equalPayment,
                firstDueDate: date(2026, 1, 27),
                paymentDay: 27
            )

            let schedule = try LoanScheduleCalculator(calendar: Fixture.calendar)
                .schedule(for: terms)

            XCTAssertEqual(
                schedule.installments.count,
                count,
                "\(count)回払いなのに\(schedule.installments.count)回になっています。"
            )
            XCTAssertEqual(
                schedule.installments.last?.balanceAfter ?? -1,
                0,
                accuracy: 0.001,
                "最終回で残高が0になっていません。"
            )
        }
    }

    /// 端数を寄せても、最終回だけが不自然に大きくなったりはしません。
    func testTheFinalInstallmentStaysCloseToTheOthers() throws {
        let terms = LoanTerms(
            principal: 1_000_000,
            annualRatePercent: 3.0,
            installmentCount: 12,
            method: .equalPayment,
            firstDueDate: date(2026, 1, 27),
            paymentDay: 27
        )

        let schedule = try LoanScheduleCalculator(calendar: Fixture.calendar)
            .schedule(for: terms)
        let first = try XCTUnwrap(schedule.installments.first)
        let last = try XCTUnwrap(schedule.installments.last)

        XCTAssertEqual(last.amount, first.amount, accuracy: 5)
    }

    /// 滞納した月は回数に数えません。数えると、滞納したぶん早く打ち切られてしまいます。
    func testMissedPeriodsDoNotConsumeTheContractedCount() throws {
        let terms = LoanTerms(
            principal: 1_000_000,
            annualRatePercent: 3.0,
            installmentCount: 12,
            method: .equalPayment,
            firstDueDate: date(2026, 1, 27),
            paymentDay: 27
        )

        let schedule = try LoanScheduleCalculator(calendar: Fixture.calendar)
            .schedule(for: terms, missedPeriods: [2, 5])

        XCTAssertEqual(schedule.paymentCount, 12, "実際に返済する回数は契約どおりのはずです。")
        XCTAssertEqual(schedule.installments.count, 14, "滞納した2ヶ月ぶん後ろへずれます。")
        XCTAssertEqual(schedule.installments.last?.balanceAfter ?? -1, 0, accuracy: 0.001)
    }

    // MARK: - 通知の時刻

    /// **返済日は0時なので、そのまま通知にすると深夜に鳴ります。**
    func testRepaymentNotificationFiresInTheMorning() throws {
        let loan = Loan(
            name: "自動車ローン",
            annualRatePercent: 3.0,
            originalPrincipal: 1_000_000,
            borrowedOn: date(2025, 12, 10),
            totalInstallments: 12,
            paymentDay: 27
        )
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)

        let planned = LoanNotificationPlanner.plannedPayments(
            loans: [loan],
            now: date(2026, 1, 5),
            limit: 12,
            calendar: Fixture.calendar
        )
        let first = try XCTUnwrap(planned.first)
        let components = Fixture.calendar.dateComponents([.hour, .minute], from: first.date)

        XCTAssertEqual(components.hour, LoanNotificationPlanner.notificationHour)
        XCTAssertEqual(components.minute, 0)
        XCTAssertNotEqual(components.hour, 0, "深夜0時に通知が出ます。")
    }

    /// 通知の日付そのものは返済日から動かしません。時刻だけを進めます。
    func testNotificationKeepsTheDueDay() throws {
        let loan = Loan(
            name: "自動車ローン",
            annualRatePercent: 3.0,
            originalPrincipal: 1_000_000,
            borrowedOn: date(2025, 12, 10),
            totalInstallments: 12,
            paymentDay: 27
        )
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)

        let planned = LoanNotificationPlanner.plannedPayments(
            loans: [loan],
            now: date(2026, 1, 5),
            limit: 12,
            calendar: Fixture.calendar
        )
        let first = try XCTUnwrap(planned.first)
        let components = Fixture.calendar.dateComponents(
            [.year, .month, .day],
            from: first.date
        )

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 27)
    }

    // MARK: - 補助

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Fixture.calendar.date(from: components) ?? .distantPast
    }
}
