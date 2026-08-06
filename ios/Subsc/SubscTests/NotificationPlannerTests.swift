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

    // MARK: - 文言

    /// 定額の費目は、通知だけで「いくら出ていくか」が分かるようにします。
    func testRenewalBodyIncludesTheBilledAmountForFixedSubscriptions() {
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
        let subscription = Subscription(
            clientID: "fixed",
            name: "Netflix",
            originalAmount: 1_590,
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

        let body = plan.first?.body ?? ""
        XCTAssertEqual(plan.first?.title, "Netflixの更新予定")
        XCTAssertTrue(
            body.contains("1,590"),
            "定額の費目は請求額を本文へ入れる。実際の本文：\(body)"
        )
    }

    /// 年払いは**月額へならさず、実際に請求される年額**を出します。
    /// 月額へならした額を通知すると、その日に引き落とされる額と食い違います。
    func testRenewalBodyUsesTheYearlyAmountForYearlySubscriptions() {
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
        let subscription = Subscription(
            clientID: "yearly",
            name: "年払い",
            originalAmount: 12_000,
            billingCycle: .yearly,
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

        let body = plan.first?.body ?? ""
        XCTAssertTrue(
            body.contains("12,000"),
            "年払いは年額をそのまま出す。実際の本文：\(body)"
        )
        XCTAssertFalse(
            body.contains("1,000"),
            "月額へならした額を出してはいけない。実際の本文：\(body)"
        )
    }

    /// 変動費は次回の請求額が決まっていないので、**金額を書きません**。
    /// 古い実績や見込みを断定して出すと、届いた通知そのものが誤りになります。
    func testRenewalBodyOmitsTheAmountForVariableSubscriptions() {
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
        let subscription = Subscription(
            clientID: "variable",
            name: "電気代",
            hasVariableAmount: true,
            originalAmount: 8_000,
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

        let body = plan.first?.body ?? ""
        XCTAssertFalse(
            body.contains("8,000"),
            "変動費に金額を書いてはいけない。実際の本文：\(body)"
        )
        XCTAssertTrue(
            body.contains("更新されます"),
            "金額が無くても、いつ更新されるかは伝える。実際の本文：\(body)"
        )
    }

    /// 米ドルの費目は、**円へ換算した額**を出します。
    /// 通知を見て支払いに備えるので、引き落とされる通貨で示します。
    func testRenewalBodyConvertsForeignCurrencyIntoYen() {
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
        let subscription = Subscription(
            clientID: "usd",
            name: "USD費目",
            originalAmount: 10,
            exchangeRate: 150,
            currency: .usd,
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

        let body = plan.first?.body ?? ""
        XCTAssertTrue(
            body.contains("1,500"),
            "米ドルは円換算して出す。実際の本文：\(body)"
        )
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
