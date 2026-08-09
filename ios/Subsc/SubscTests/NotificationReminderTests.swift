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

    /// **ここが本丸。** ローンの識別子も接頭辞 `subsc-` で始まるため、
    /// 更新日通知の名前空間から明示的に除外しないと、**再スケジュールのたびに全部消えます。**
    func testLoanIdentifiersAreNotSweptAwayByRenewals() {
        let loan = NotificationIdentifier.loanPayment(clientID: clientID, periodKey: 202607)

        XCTAssertTrue(NotificationNamespace.loan.contains(loan))
        XCTAssertFalse(NotificationNamespace.renewal.contains(loan))
        XCTAssertFalse(NotificationNamespace.reminder.contains(loan))
    }

    func testRescheduledRenewalsDoNotSweepAwayLoanPayments() {
        let loan = NotificationIdentifier.loanPayment(clientID: clientID, periodKey: 202607)
        let staleRenewal = NotificationIdentifier.renewal(
            clientID: clientID,
            cycleKey: "2026-06-25T09:00:00",
            suffix: "day-1"
        )

        let obsolete = NotificationIdentifier.obsolete(
            pending: [loan, staleRenewal],
            desired: [],
            in: .renewal
        )

        XCTAssertEqual(obsolete, [staleRenewal])
    }

    func testRescheduledLoanPaymentsDoNotSweepAwayRenewalsOrReminders() {
        let renewal = NotificationIdentifier.renewal(
            clientID: clientID,
            cycleKey: "2026-07-25T09:00:00",
            suffix: "day-1"
        )
        let reminder = NotificationIdentifier.reminder(clientID: clientID, periodKey: 202607)
        let staleLoan = NotificationIdentifier.loanPayment(clientID: clientID, periodKey: 202606)

        let obsolete = NotificationIdentifier.obsolete(
            pending: [renewal, reminder, staleLoan],
            desired: [],
            in: .loan
        )

        XCTAssertEqual(obsolete, [staleLoan])
    }

    /// 契約を消したときに、その契約ぶんの通知だけを取り消せること。
    func testAllCollectsLoanIdentifiersForTheSameClient() {
        let loan = NotificationIdentifier.loanPayment(clientID: clientID, periodKey: 202607)
        let other = NotificationIdentifier.loanPayment(clientID: "other", periodKey: 202607)

        let collected = NotificationIdentifier.all(pending: [loan, other], clientID: clientID)

        XCTAssertEqual(collected, [loan])
    }

    func testEveryNamespaceClaimsOnlyItsOwnIdentifiers() {
        let identifiers = [
            NotificationIdentifier.renewal(clientID: clientID, cycleKey: "k", suffix: "day-1"),
            NotificationIdentifier.reminder(clientID: clientID, periodKey: 202607),
            NotificationIdentifier.loanPayment(clientID: clientID, periodKey: 202607)
        ]

        for identifier in identifiers {
            let owners = NotificationNamespace.allCases.filter { $0.contains(identifier) }
            XCTAssertEqual(owners.count, 1, "\(identifier) を持つ名前空間が1つではありません")
        }
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


/// harutoさんの報告（2026-08-09）の再現です。
/// 8/10更新の費目を登録し、通知を「前日の13:30」に設定したが、8/9 13:30に届かなかった。
@MainActor
final class RenewalNotificationReproTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        DateComponents(calendar: calendar, year: y, month: m, day: d, hour: h, minute: min).date!
    }

    /// 8/9の12:00に登録した時点で、8/9 13:30の予約が作られること。
    func testDayBeforeNotificationIsPlanned() {
        let subscription = Subscription(
            name: "テスト",
            originalAmount: 1_000,
            renewalDate: date(2026, 8, 10),
            notificationsEnabled: true,
            notificationHour: 13,
            notificationMinute: 30,
            leadDays: [1]
        )

        let planned = NotificationService.plannedNotifications(
            subscriptions: [subscription],
            now: date(2026, 8, 9, 12, 0),
            calendar: calendar
        )

        let expected = date(2026, 8, 9, 13, 30)
        XCTAssertTrue(
            planned.contains { $0.date == expected },
            "8/9 13:30 の予約がありません。作られた予約：\(planned.map { ($0.date, $0.identifier) })"
        )
    }
}


/// 予約が iOS の上限（64件）を超えないことを縛るテストです。
///
/// **これを縛っていなかったために、費目を1件足した直後の通知が届きませんでした（2026-08-09）。**
/// 費目11件で予約したい候補は204件あり、枠を大きく超えていました。
/// 超過は例外にならず黙って捨てられるので、**件数は数えて縛るしかありません。**
@MainActor
final class NotificationBudgetTests: XCTestCase {
    /// iOSが1つのアプリに保持できる予約の数です。
    private let systemLimit = 64

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        DateComponents(calendar: calendar, year: y, month: m, day: d, hour: h, minute: min).date!
    }

    /// harutoさんの端末と同じ規模（費目11件・一部は1/3/7日前）で、
    /// 更新日通知の計画が枠に収まること。
    func testPlannedRenewalsStayWithinTheBudget() {
        let subscriptions = (1...11).map { index -> Subscription in
            Subscription(
                name: "費目\(index)",
                originalAmount: 1_000,
                renewalDate: date(2026, 9, min(index, 28)),
                notificationsEnabled: true,
                leadDays: index <= 3 ? [1, 3, 7] : [1]
            )
        }

        let planned = NotificationService.plannedNotifications(
            subscriptions: subscriptions,
            now: date(2026, 8, 9, 12, 0),
            limit: 36,
            calendar: calendar
        )

        XCTAssertLessThanOrEqual(planned.count, 36)
        XCTAssertLessThanOrEqual(planned.count, systemLimit)
    }

    /// **どの費目も、いちばん近い1件だけは必ず予約されること。**
    /// 枠が足りないときに一部の費目が丸ごと無視されると、その費目の通知は永遠に来ません。
    func testEverySubscriptionKeepsItsSoonestNotification() {
        let subscriptions = (1...11).map { index -> Subscription in
            Subscription(
                name: "費目\(index)",
                originalAmount: 1_000,
                renewalDate: date(2026, 9, min(index, 28)),
                notificationsEnabled: true,
                leadDays: [1, 3, 7]
            )
        }

        let planned = NotificationService.plannedNotifications(
            subscriptions: subscriptions,
            now: date(2026, 8, 9, 12, 0),
            limit: 36,
            calendar: calendar
        )

        let covered = Set(planned.map(\.clientID))
        XCTAssertEqual(
            covered.count,
            subscriptions.count,
            "予約が1件も作られない費目があります。枠の配り方が偏っています。"
        )
    }

    /// 先読みするサイクル数を増やしすぎると、他の費目の枠を奪います。
    /// **1つの費目が枠を独占しないこと。**
    func testASingleSubscriptionDoesNotMonopolizeTheBudget() {
        let subscription = Subscription(
            name: "毎月",
            originalAmount: 1_000,
            renewalDate: date(2026, 8, 20),
            notificationsEnabled: true,
            leadDays: [1]
        )

        let planned = NotificationService.plannedNotifications(
            subscriptions: [subscription],
            now: date(2026, 8, 9, 12, 0),
            calendar: calendar
        )

        XCTAssertLessThanOrEqual(
            planned.count,
            5,
            "1つの費目で\(planned.count)件を占めています。費目が増えると枠が足りません。"
        )
    }
}

/// 「直近の更新に間に合わない」を画面で知らせるための判定です。
@MainActor
final class NotifiableTimeTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        DateComponents(calendar: calendar, year: y, month: m, day: d, hour: h, minute: min).date!
    }

    /// 8/9の12:00に「8/10更新・前日13:30」なら、まだ間に合います。
    func testStillNotifiableBeforeTheLeadTime() {
        XCTAssertTrue(
            NotificationService.hasNotifiableTime(
                renewalDate: date(2026, 8, 10),
                hour: 13,
                minute: 30,
                leadDays: [1],
                leadHours: [],
                now: date(2026, 8, 9, 12, 0),
                calendar: calendar
            )
        )
    }

    /// **8/9の14:00に同じ設定を入れると、直近の1回は間に合いません。**
    /// ここを黙って捨てていたため、通知ONなのに1件も予約されない状態が起きえました。
    func testNotNotifiableAfterTheLeadTimeHasPassed() {
        XCTAssertFalse(
            NotificationService.hasNotifiableTime(
                renewalDate: date(2026, 8, 10),
                hour: 13,
                minute: 30,
                leadDays: [1],
                leadHours: [],
                now: date(2026, 8, 9, 14, 0),
                calendar: calendar
            )
        )
    }

    /// タイミングを1つも選んでいなければ、通知は届きません。
    func testNoLeadTimesMeansNoNotification() {
        XCTAssertFalse(
            NotificationService.hasNotifiableTime(
                renewalDate: date(2026, 8, 10),
                hour: 13,
                minute: 30,
                leadDays: [],
                leadHours: [],
                now: date(2026, 8, 9, 12, 0),
                calendar: calendar
            )
        )
    }

    /// 間に合わない日単位があっても、時間単位が生きていれば届きます。
    func testHourLeadCanStillBeNotifiable() {
        XCTAssertTrue(
            NotificationService.hasNotifiableTime(
                renewalDate: date(2026, 8, 10),
                hour: 13,
                minute: 30,
                leadDays: [1],
                leadHours: [2],
                now: date(2026, 8, 9, 14, 0),
                calendar: calendar
            )
        )
    }
}
