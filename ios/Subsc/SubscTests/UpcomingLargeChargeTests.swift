import XCTest
@testable import Subsc

/// 年払いは更新月にだけ全額が立つため、**その月だけ合計が跳ね上がります**。
/// 不意打ちにしないよう、先に知らせるための計算です。
final class UpcomingLargeChargeTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func yearly(_ name: String, _ amount: Double, renewal: Date) -> Subscription {
        Subscription(
            name: name,
            originalAmount: amount,
            billingCycle: .yearly,
            renewalDate: renewal
        )
    }

    func testTheRenewalMonthOfAYearlyPlanIsAnnounced() {
        let subscription = yearly("年払い", 12_000, renewal: date(2026, 10, 20))

        let notices = UpcomingLargeCharge.notices(
            subscriptions: [subscription],
            now: date(2026, 8, 4),
            calendar: calendar
        )

        XCTAssertEqual(notices.count, 1)
        XCTAssertEqual(notices.first?.periodKey, 202610)
        XCTAssertEqual(notices.first?.total, 12_000)
        XCTAssertEqual(notices.first?.names, ["年払い"])
    }

    /// **今月ぶんは予告しません。** すでに払っているか、これから数日で払うだけで、
    /// レポートの合計にも出ています。知らせる意味があるのは先の月だけです。
    func testThisMonthIsNotAnnounced() {
        let subscription = yearly("今月ぶん", 12_000, renewal: date(2026, 8, 20))

        let notices = UpcomingLargeCharge.notices(
            subscriptions: [subscription],
            now: date(2026, 8, 4),
            calendar: calendar
        )

        XCTAssertTrue(notices.isEmpty)
    }

    /// 遠すぎる先を出しても行動につながりません。既定では3ヶ月先までにします。
    func testMonthsBeyondTheHorizonAreNotAnnounced() {
        let subscription = yearly("ずっと先", 12_000, renewal: date(2027, 3, 20))

        let notices = UpcomingLargeCharge.notices(
            subscriptions: [subscription],
            now: date(2026, 8, 4),
            calendar: calendar
        )

        XCTAssertTrue(notices.isEmpty)
    }

    func testSeveralPlansInTheSameMonthAreCombined() {
        let plans = [
            yearly("A", 12_000, renewal: date(2026, 9, 3)),
            yearly("B", 18_000, renewal: date(2026, 9, 25))
        ]

        let notices = UpcomingLargeCharge.notices(
            subscriptions: plans,
            now: date(2026, 8, 4),
            calendar: calendar
        )

        XCTAssertEqual(notices.count, 1)
        XCTAssertEqual(notices.first?.total, 30_000)
        XCTAssertEqual(notices.first?.names, ["B", "A"], "金額の大きい順に並べます")
    }

    func testNoticesAreSortedByMonth() {
        let plans = [
            yearly("11月", 5_000, renewal: date(2026, 11, 1)),
            yearly("9月", 5_000, renewal: date(2026, 9, 1))
        ]

        let notices = UpcomingLargeCharge.notices(
            subscriptions: plans,
            now: date(2026, 8, 4),
            calendar: calendar
        )

        XCTAssertEqual(notices.map(\.periodKey), [202609, 202611])
    }

    /// 月払いは毎月同じなので跳ねません。**予告の対象にしません。**
    func testMonthlyPlansAreIgnored() {
        let subscription = Subscription(
            name: "月払い",
            originalAmount: 50_000,
            billingCycle: .monthly,
            renewalDate: date(2026, 9, 10)
        )

        let notices = UpcomingLargeCharge.notices(
            subscriptions: [subscription],
            now: date(2026, 8, 4),
            calendar: calendar
        )

        XCTAssertTrue(notices.isEmpty)
    }

    func testPausedPlansAreIgnored() {
        let subscription = yearly("停止中", 12_000, renewal: date(2026, 9, 10))
        subscription.state = .paused

        let notices = UpcomingLargeCharge.notices(
            subscriptions: [subscription],
            now: date(2026, 8, 4),
            calendar: calendar
        )

        XCTAssertTrue(notices.isEmpty)
    }

    /// 解約済み（終了日が過ぎている）の費目は、もう払いません。
    func testPlansThatEndBeforeTheChargeAreIgnored() {
        let subscription = yearly("解約済み", 12_000, renewal: date(2026, 9, 10))
        subscription.endDate = date(2026, 8, 31)

        let notices = UpcomingLargeCharge.notices(
            subscriptions: [subscription],
            now: date(2026, 8, 4),
            calendar: calendar
        )

        XCTAssertTrue(notices.isEmpty)
    }

    /// 契約の開始前に更新月が来ることはありません。
    func testPlansThatStartAfterTheChargeAreIgnored() {
        let subscription = yearly("来年から", 12_000, renewal: date(2026, 9, 10))
        subscription.startDate = date(2026, 12, 1)

        let notices = UpcomingLargeCharge.notices(
            subscriptions: [subscription],
            now: date(2026, 8, 4),
            calendar: calendar
        )

        XCTAssertTrue(notices.isEmpty)
    }

    /// 12月の次は翌年1月です。年をまたいでも数え違えません。
    func testTheHorizonCrossesTheNewYear() {
        let subscription = yearly("1月ぶん", 12_000, renewal: date(2026, 1, 15))

        let notices = UpcomingLargeCharge.notices(
            subscriptions: [subscription],
            now: date(2026, 12, 10),
            calendar: calendar
        )

        XCTAssertEqual(notices.first?.periodKey, 202701)
    }
}
