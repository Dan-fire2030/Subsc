import XCTest
@testable import Subsc

/// 「これから出ていく」の時間軸に何を、いくらで並べるかのテストです。
///
/// **2026-08-08の独立レビューで見つかった2件を押さえます。**
/// どちらも利用者には「確かな情報」として読まれるので、間違っていると気づかれません。
final class UpcomingTimelineItemTests: XCTestCase {
    private enum Fixture {
        static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt
            return calendar
        }

        static let now = DateComponents(
            calendar: calendar,
            year: 2026,
            month: 1,
            day: 15
        ).date ?? .distantPast
    }

    // MARK: - 変動費の額

    /// **変動費は次回の請求額が決まっていないので、金額を出しません。**
    ///
    /// 通知（`NotificationService.renewalBody`）は同じ理由で金額を書かない実装になっています。
    /// 時間軸だけが確定額のように出すと、**同じアプリの中で言うことが食い違います**。
    /// 出ていた値は `originalAmount` 由来で、次回の請求額とは無関係でした。
    func testVariableCostShowsNoAmountBecauseTheNextChargeIsUnknown() {
        let subscription = Subscription(
            name: "電気代",
            originalAmount: 8_000,
            renewalDate: date(2026, 2, 1)
        )
        subscription.hasVariableAmount = true

        let item = DashboardListItem.subscription(subscription)

        XCTAssertNil(
            item.nextDueAmount,
            "変動費に金額を出してはいけない。通知が金額を書かないのと同じ理由"
        )
    }

    /// 定額の費目はこれまでどおり額を出します。
    func testFixedCostStillShowsItsAmount() {
        let subscription = Subscription(
            name: "動画",
            originalAmount: 1_590,
            renewalDate: date(2026, 2, 1)
        )

        let item = DashboardListItem.subscription(subscription)

        XCTAssertEqual(item.nextDueAmount, 1_590)
    }

    /// 年払いは年額のまま出します。次に出ていくのは1/12ではなく全額だからです。
    func testYearlyCostShowsTheWholeAmount() {
        let subscription = Subscription(
            name: "年払いの何か",
            originalAmount: 12_000,
            billingCycle: .yearly,
            renewalDate: date(2026, 2, 1)
        )

        let item = DashboardListItem.subscription(subscription)

        XCTAssertEqual(item.nextDueAmount, 12_000, "月額へならしてはいけない")
    }

    // MARK: - 過去の期日

    /// **「これから出ていく」に過ぎた期日を並べません。**
    ///
    /// 更新日の繰り越しは起動時に走りますが、保存に失敗して巻き戻った場合や、
    /// 繰り越しが終わる前の描画では過去日が残ります。そのとき見出しと中身が食い違い、
    /// 「あと何日か」の代わりに「期日超過」が並びます。
    func testPastDueItemsAreExcludedFromTheUpcomingTimeline() {
        let past = Subscription(name: "過ぎた費目", originalAmount: 500, renewalDate: date(2026, 1, 10))
        let today = Subscription(name: "今日の費目", originalAmount: 600, renewalDate: date(2026, 1, 15))
        let future = Subscription(name: "先の費目", originalAmount: 700, renewalDate: date(2026, 2, 1))

        let items = DashboardListBuilder.upcomingItems(
            subscriptions: [past, today, future],
            loans: [],
            costTypeFilter: .all,
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(
            items.map(\.name),
            ["今日の費目", "先の費目"],
            "過ぎた期日は外し、今日は残す"
        )
    }

    /// 期日を持たないもの（完済した借入など）は軸の上に置けないので外します。
    func testItemsWithoutADueDateAreExcluded() {
        let subscription = Subscription(name: "費目", originalAmount: 500, renewalDate: date(2026, 2, 1))

        let items = DashboardListBuilder.upcomingItems(
            subscriptions: [subscription],
            loans: [],
            costTypeFilter: .all,
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertTrue(items.allSatisfy { $0.nextDueDate != nil })
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateComponents(calendar: Fixture.calendar, year: year, month: month, day: day).date
            ?? .distantPast
    }
}
