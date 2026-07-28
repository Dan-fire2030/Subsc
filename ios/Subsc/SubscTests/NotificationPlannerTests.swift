import XCTest
@testable import Subsc

@MainActor
final class NotificationPlannerTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testPlannerGivesEachSubscriptionAFirstSlotBeforeAdditionalSlots() {
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 1,
            day: 1
        ))!
        let renewal = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 1,
            day: 15
        ))!
        let first = makeSubscription(clientID: "a", renewal: renewal)
        let second = makeSubscription(clientID: "b", renewal: renewal)

        let plan = NotificationService.plannedNotifications(
            subscriptions: [first, second],
            now: now,
            limit: 3,
            calendar: calendar
        )

        XCTAssertEqual(plan.map(\.clientID), ["a", "b", "a"])
    }

    func testPlannerDoesNotLetOneSubscriptionConsumeTheGlobalLimit() {
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 1,
            day: 1
        ))!
        let renewal = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 2,
            day: 1
        ))!
        let subscriptions = (0..<70).map {
            makeSubscription(clientID: String(format: "%03d", $0), renewal: renewal)
        }

        let plan = NotificationService.plannedNotifications(
            subscriptions: subscriptions,
            now: now,
            limit: 64,
            calendar: calendar
        )

        XCTAssertEqual(plan.count, 64)
        XCTAssertEqual(Set(plan.map(\.clientID)).count, 64)
    }

    func testPlannerExcludesNotificationDatesInThePast() {
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 1,
            day: 1,
            hour: 10
        ))!
        let renewal = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 1,
            day: 2
        ))!
        let subscription = Subscription(
            clientID: "past-boundary",
            name: "Boundary",
            originalAmount: 1_000,
            renewalDate: renewal,
            notificationHour: 9,
            notificationMinute: 0,
            leadDays: [1]
        )

        let plan = NotificationService.plannedNotifications(
            subscriptions: [subscription],
            now: now,
            calendar: calendar
        )

        XCTAssertTrue(plan.allSatisfy { $0.date > now })
        XCTAssertFalse(plan.contains {
            calendar.isDate($0.date, inSameDayAs: now)
        })
    }

    private func makeSubscription(clientID: String, renewal: Date) -> Subscription {
        Subscription(
            clientID: clientID,
            name: clientID,
            originalAmount: 1_000,
            renewalDate: renewal,
            notificationHour: 9,
            notificationMinute: 0,
            leadDays: [1, 3],
            leadHours: [1]
        )
    }
}
