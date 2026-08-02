import XCTest
@testable import Subsc

/// 返済日通知を「何日前」に寄せる設定のテストです。
///
/// **当日では口座への入金が間に合いません。** 費目の更新日通知に「何日前」があるのと同じ理由で、
/// 借入にも必要でした。設定は `UserDefaults` に閉じ、CloudKitのスキーマは増やしていません。
final class LoanNotificationLeadTests: XCTestCase {
    private enum Fixture {
        static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt
            return calendar
        }
    }

    // MARK: - 通知の日時

    func testSameDayLeadFiresOnTheDueDate() throws {
        let loan = try makeSynchronizedLoan()

        let planned = LoanNotificationPlanner.plannedPayments(
            loans: [loan],
            now: date(2026, 1, 5),
            limit: 12,
            lead: .sameDay,
            hour: 9,
            calendar: Fixture.calendar
        )
        let first = try XCTUnwrap(planned.first)

        XCTAssertEqual(first.date, dateTime(2026, 1, 27, hour: 9))
    }

    func testThreeDayLeadFiresEarlier() throws {
        let loan = try makeSynchronizedLoan()

        let planned = LoanNotificationPlanner.plannedPayments(
            loans: [loan],
            now: date(2026, 1, 5),
            limit: 12,
            lead: .threeDays,
            hour: 9,
            calendar: Fixture.calendar
        )
        let first = try XCTUnwrap(planned.first)

        XCTAssertEqual(first.date, dateTime(2026, 1, 24, hour: 9))
    }

    func testHourIsRespected() throws {
        let loan = try makeSynchronizedLoan()

        let planned = LoanNotificationPlanner.plannedPayments(
            loans: [loan],
            now: date(2026, 1, 5),
            limit: 12,
            lead: .sameDay,
            hour: 20,
            calendar: Fixture.calendar
        )
        let first = try XCTUnwrap(planned.first)

        XCTAssertEqual(first.date, dateTime(2026, 1, 27, hour: 20))
    }

    // MARK: - 過去になる回を落とすこと

    /// **何日前に寄せると、通知の時刻がもう過ぎていることがあります。**
    /// 返済日ではなく実際に鳴る時刻で判断しないと、過去日時の通知を予約してしまいます。
    func testNotificationsWhoseFireTimeHasPassedAreDropped() throws {
        let loan = try makeSynchronizedLoan()

        // 1月25日時点では、1月27日の3日前（1月24日9時）はもう過ぎています。
        let planned = LoanNotificationPlanner.plannedPayments(
            loans: [loan],
            now: date(2026, 1, 25),
            limit: 12,
            lead: .threeDays,
            hour: 9,
            calendar: Fixture.calendar
        )

        XCTAssertFalse(
            planned.contains { $0.date < date(2026, 1, 25) },
            "過ぎた日時の通知が残っています。"
        )
        XCTAssertEqual(planned.first?.date, dateTime(2026, 2, 24, hour: 9))
    }

    /// 当日設定でも、その日の9時を過ぎていれば落とします。
    func testSameDayNotificationIsDroppedAfterTheHourHasPassed() throws {
        let loan = try makeSynchronizedLoan()

        let planned = LoanNotificationPlanner.plannedPayments(
            loans: [loan],
            now: dateTime(2026, 1, 27, hour: 12),
            limit: 12,
            lead: .sameDay,
            hour: 9,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(planned.first?.date, dateTime(2026, 2, 27, hour: 9))
    }

    /// **返済日当日の朝（通知時刻より前）に開いても、その日の通知が予約されること。**
    ///
    /// 返済日は0時なので、「返済日が今より後か」で絞ると当日ぶんが落ちます。
    /// 0時30分に開いた利用者は、9時の通知を受け取れませんでした。
    /// 判定は返済日ではなく、実際に鳴る時刻で行う必要があります。
    func testTodaysNotificationSurvivesWhenOpenedBeforeTheHour() throws {
        let loan = try makeSynchronizedLoan()

        let planned = LoanNotificationPlanner.plannedPayments(
            loans: [loan],
            now: dateTime(2026, 1, 27, hour: 0),
            limit: 12,
            lead: .sameDay,
            hour: 9,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(
            planned.first?.date,
            dateTime(2026, 1, 27, hour: 9),
            "返済日当日の通知が落ちています。"
        )
    }

    /// 何日前に寄せた場合も、まだ鳴っていない直近の回から並びます。
    func testTheNearestPaymentIsStillPlannedWhenLeadIsLong() throws {
        let loan = try makeSynchronizedLoan()

        let planned = LoanNotificationPlanner.plannedPayments(
            loans: [loan],
            now: date(2026, 1, 20),
            limit: 12,
            lead: .oneWeek,
            hour: 9,
            calendar: Fixture.calendar
        )

        // 1月27日の1週間前は1月20日9時。0時に開いた時点ではまだ先です。
        XCTAssertEqual(planned.first?.date, dateTime(2026, 1, 20, hour: 9))
    }

    // MARK: - 設定の保存

    func testSettingsPersistAndDistinguishSameDayFromUnset() {
        let suiteName = "LoanNotificationLeadTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let fresh = LoanNotificationSettings(defaults: defaults)
        XCTAssertEqual(fresh.lead, LoanNotificationSettings.Defaults.lead)
        XCTAssertEqual(fresh.hour, LoanNotificationSettings.Defaults.hour)

        fresh.lead = .sameDay
        fresh.hour = 7

        let reloaded = LoanNotificationSettings(defaults: defaults)
        XCTAssertEqual(reloaded.lead, .sameDay, "当日（0）が未設定と混同されています。")
        XCTAssertEqual(reloaded.hour, 7)
    }

    /// 保存値が壊れていても既定へ倒します。起動を止めないためです。
    func testBrokenStoredValuesFallBackToDefaults() {
        let suiteName = "LoanNotificationLeadTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(99, forKey: "loanNotification.leadDays")
        defaults.set(48, forKey: "loanNotification.hour")

        let settings = LoanNotificationSettings(defaults: defaults)

        XCTAssertEqual(settings.lead, LoanNotificationSettings.Defaults.lead)
        XCTAssertEqual(settings.hour, LoanNotificationSettings.Defaults.hour)
    }

    // MARK: - 補助

    private func makeSynchronizedLoan() throws -> Loan {
        let loan = Loan(
            name: "自動車ローン",
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
        dateTime(year, month, day, hour: 0)
    }

    private func dateTime(_ year: Int, _ month: Int, _ day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return Fixture.calendar.date(from: components) ?? .distantPast
    }
}
