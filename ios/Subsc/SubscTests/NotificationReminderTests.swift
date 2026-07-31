import XCTest
@testable import Subsc

/// 更新日通知と月末リマインドが、互いを消し合わないことを担保するテストです。
///
/// 既存の `reconcile` は「接頭辞が一致する予約のうち、計画に無いものを消す」作りです。
/// 両者を同じ名前空間に置くと、片方の再スケジュールがもう片方を全部消します。
final class NotificationIdentifierTests: XCTestCase {
    private let clientID = "11111111-2222-3333-4444-555555555555"

    func testRenewalAndReminderIdentifiersBelongToDifferentNamespaces() {
        let renewal = NotificationIdentifier.renewal(
            clientID: clientID,
            cycleKey: "2026-07-25T09:00:00",
            suffix: "day-1"
        )
        let reminder = NotificationIdentifier.reminder(clientID: clientID, periodKey: 202607)

        XCTAssertTrue(NotificationNamespace.renewal.contains(renewal))
        XCTAssertFalse(NotificationNamespace.reminder.contains(renewal))

        XCTAssertTrue(NotificationNamespace.reminder.contains(reminder))
        // ここが本丸：リマインドは接頭辞 subsc- で始まるが、更新日通知の名前空間には入らない
        XCTAssertFalse(NotificationNamespace.renewal.contains(reminder))
    }

    func testRescheduledRenewalsDoNotSweepAwayReminders() {
        let reminder = NotificationIdentifier.reminder(clientID: clientID, periodKey: 202607)
        let staleRenewal = NotificationIdentifier.renewal(
            clientID: clientID,
            cycleKey: "2026-06-25T09:00:00",
            suffix: "day-1"
        )

        let obsolete = NotificationIdentifier.obsolete(
            pending: [reminder, staleRenewal],
            desired: [],
            in: .renewal
        )

        XCTAssertEqual(obsolete, [staleRenewal])
    }

    func testRescheduledRemindersDoNotSweepAwayRenewals() {
        let renewal = NotificationIdentifier.renewal(
            clientID: clientID,
            cycleKey: "2026-07-25T09:00:00",
            suffix: "day-1"
        )
        let staleReminder = NotificationIdentifier.reminder(clientID: clientID, periodKey: 202605)

        let obsolete = NotificationIdentifier.obsolete(
            pending: [renewal, staleReminder],
            desired: [],
            in: .reminder
        )

        XCTAssertEqual(obsolete, [staleReminder])
    }

    func testStillPlannedIdentifiersAreKept() {
        let renewal = NotificationIdentifier.renewal(
            clientID: clientID,
            cycleKey: "2026-07-25T09:00:00",
            suffix: "day-1"
        )

        let obsolete = NotificationIdentifier.obsolete(
            pending: [renewal],
            desired: [renewal],
            in: .renewal
        )

        XCTAssertTrue(obsolete.isEmpty)
    }

    func testDeletingACostTargetsBothNamespaces() {
        let renewal = NotificationIdentifier.renewal(
            clientID: clientID,
            cycleKey: "2026-07-25T09:00:00",
            suffix: "day-1"
        )
        let reminder = NotificationIdentifier.reminder(clientID: clientID, periodKey: 202607)
        let otherCost = NotificationIdentifier.reminder(clientID: "別の費目", periodKey: 202607)

        let identifiers = NotificationIdentifier.all(
            pending: [renewal, reminder, otherCost],
            clientID: clientID
        )

        XCTAssertEqual(Set(identifiers), [renewal, reminder])
    }
}

/// 月末リマインドを、いつ・どの費目に積むかのテストです。
final class ReminderPlannerTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour)
        ) ?? .now
    }

    private func makeUtility(
        name: String = "電気代",
        variable: Bool = true,
        state: SubscriptionState = .active,
        notificationsEnabled: Bool = true
    ) -> Subscription {
        let subscription = Subscription(
            name: name,
            costType: .utility,
            hasVariableAmount: variable,
            originalAmount: 0,
            state: state,
            renewalDate: date(2026, 7, 25),
            notificationsEnabled: notificationsEnabled
        )
        return subscription
    }

    func testAVariableCostWithoutThisMonthsRecordIsRemindedOnTheLastDayOfTheMonth() {
        let electricity = makeUtility()

        let planned = ReminderPlanner.plannedReminders(
            subscriptions: [electricity],
            now: date(2026, 7, 15, 9),
            limit: 16,
            calendar: calendar
        )

        XCTAssertEqual(planned.first?.date, date(2026, 7, 31, 9))
    }

    func testTheReminderUsesTheCostsOwnNotificationTime() {
        let electricity = makeUtility()
        electricity.notificationHour = 20
        electricity.notificationMinute = 30

        let planned = ReminderPlanner.plannedReminders(
            subscriptions: [electricity],
            now: date(2026, 7, 15, 9),
            limit: 16,
            calendar: calendar
        )

        let expected = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 31, hour: 20, minute: 30)
        )
        XCTAssertEqual(planned.first?.date, expected)
    }

    func testAMonthThatAlreadyHasARecordIsNotReminded() {
        let electricity = makeUtility()
        AmountEntryStore.record(amount: 8200, year: 2026, month: 7, on: electricity)

        let planned = ReminderPlanner.plannedReminders(
            subscriptions: [electricity],
            now: date(2026, 7, 15, 9),
            limit: 16,
            calendar: calendar
        )

        XCTAssertFalse(planned.contains { $0.identifier.hasSuffix("202607") })
    }

    func testFixedCostsAreNeverReminded() {
        let netflix = makeUtility(name: "Netflix", variable: false)

        let planned = ReminderPlanner.plannedReminders(
            subscriptions: [netflix],
            now: date(2026, 7, 15, 9),
            limit: 16,
            calendar: calendar
        )

        XCTAssertTrue(planned.isEmpty)
    }

    func testPausedCostsAreNotReminded() {
        let electricity = makeUtility(state: .paused)

        let planned = ReminderPlanner.plannedReminders(
            subscriptions: [electricity],
            now: date(2026, 7, 15, 9),
            limit: 16,
            calendar: calendar
        )

        XCTAssertTrue(planned.isEmpty)
    }

    func testCostsWithNotificationsTurnedOffAreNotReminded() {
        let electricity = makeUtility(notificationsEnabled: false)

        let planned = ReminderPlanner.plannedReminders(
            subscriptions: [electricity],
            now: date(2026, 7, 15, 9),
            limit: 16,
            calendar: calendar
        )

        XCTAssertTrue(planned.isEmpty)
    }

    func testLaterMonthsAreScheduledAheadSoTheAppDoesNotNeedToBeOpened() {
        let electricity = makeUtility()

        let planned = ReminderPlanner.plannedReminders(
            subscriptions: [electricity],
            now: date(2026, 7, 15, 9),
            limit: 16,
            calendar: calendar
        )

        // 7月・8月・9月の月末。2月や30日までの月でも末日になっていること
        XCTAssertEqual(
            planned.map(\.date),
            [date(2026, 7, 31, 9), date(2026, 8, 31, 9), date(2026, 9, 30, 9)]
        )
    }

    func testThisMonthIsSkippedOnceItsReminderTimeHasPassed() {
        let electricity = makeUtility()

        let planned = ReminderPlanner.plannedReminders(
            subscriptions: [electricity],
            now: date(2026, 7, 31, 10),
            limit: 16,
            calendar: calendar
        )

        XCTAssertEqual(planned.first?.date, date(2026, 8, 31, 9))
    }

    func testTheLimitCapsHowManyRemindersArePlanned() {
        let costs = (1...10).map { makeUtility(name: "費目\($0)") }

        let planned = ReminderPlanner.plannedReminders(
            subscriptions: costs,
            now: date(2026, 7, 15, 9),
            limit: 4,
            calendar: calendar
        )

        XCTAssertEqual(planned.count, 4)
    }

    func testRemindersAreOrderedByDateSoTheNearestOnesSurviveTheLimit() {
        let electricity = makeUtility()

        let planned = ReminderPlanner.plannedReminders(
            subscriptions: [electricity],
            now: date(2026, 7, 15, 9),
            limit: 2,
            calendar: calendar
        )

        XCTAssertEqual(planned.map(\.date), [date(2026, 7, 31, 9), date(2026, 8, 31, 9)])
    }
}
