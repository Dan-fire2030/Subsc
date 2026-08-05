import XCTest
@testable import Subsc

/// 保存されている費目・借入から、猫の状態を決める材料を組み立てる部分です。
final class CatMoodContextTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    /// 2026年8月10日。月末まで日があるので、催促の条件には掛かりません。
    private var now: Date {
        DateComponents(calendar: calendar, year: 2026, month: 8, day: 10).date!
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateComponents(calendar: calendar, year: year, month: month, day: day).date!
    }

    private func mood(subscriptions: [Subscription], loans: [Loan] = [], at moment: Date? = nil) -> CatMood {
        CatMoodContext.mood(
            subscriptions: subscriptions,
            loans: loans,
            now: moment ?? now,
            calendar: calendar
        )
    }

    func testNoRegistrationsGuides() {
        XCTAssertEqual(mood(subscriptions: []), .guiding)
    }

    /// 毎月同じ額なら、平均と一致するので平常です。
    func testSteadyMonthlyCostsStayCalm() {
        let subscription = Subscription(
            name: "Netflix",
            originalAmount: 1_980,
            renewalDate: date(2026, 8, 28),
            startDate: date(2025, 1, 1)
        )

        XCTAssertEqual(mood(subscriptions: [subscription]), .calm)
    }

    /// **今月だけ年払いが立つ月は、平均より大きく増えます。**
    /// 年払いは更新月にだけ全額が立つため、その月の合計が跳ねます。
    func testAYearlyChargeLandingThisMonthWorries() {
        let steady = Subscription(
            name: "Netflix",
            originalAmount: 1_980,
            renewalDate: date(2026, 8, 28),
            startDate: date(2025, 1, 1)
        )
        let yearly = Subscription(
            name: "Adobe CC",
            originalAmount: 28_776,
            billingCycle: .yearly,
            renewalDate: date(2026, 8, 20),
            startDate: date(2025, 8, 20)
        )

        XCTAssertEqual(mood(subscriptions: [steady, yearly]), .worried)
    }

    /// **来月以降に年払いが控えていれば見張ります。** 今月の合計には出てこないため、
    /// 予告と同じ材料で判断します。
    func testAYearlyChargeComingNextMonthWatches() {
        let steady = Subscription(
            name: "Netflix",
            originalAmount: 1_980,
            renewalDate: date(2026, 8, 28),
            startDate: date(2025, 1, 1)
        )
        let yearly = Subscription(
            name: "Adobe CC",
            originalAmount: 28_776,
            billingCycle: .yearly,
            renewalDate: date(2026, 9, 20),
            startDate: date(2025, 9, 20)
        )

        XCTAssertEqual(mood(subscriptions: [steady, yearly]), .watching)
    }

    /// 変動費の金額が未入力のまま月末が近ければ催促します。
    func testUnenteredVariableCostNearMonthEndNudges() {
        let variable = Subscription(
            name: "電気代",
            hasVariableAmount: true,
            originalAmount: 0,
            renewalDate: date(2026, 8, 28),
            startDate: date(2025, 1, 1)
        )

        XCTAssertEqual(
            mood(subscriptions: [variable], at: date(2026, 8, 28)),
            .nudging
        )
    }

    /// 停止中の費目しか無くても、登録はあるので案内には戻しません。
    ///
    /// **停止すると今月の合計は0円になり、過去の月には計上されたままです**
    /// （`ReportCalculator` は「停止は今の状態であって過去の事実ではない」と扱います）。
    /// つまり平均より減っているので、ごきげんになります。止めたぶん出費が減ったのは事実です。
    func testOnlyPausedSubscriptionsArePleased() {
        let paused = Subscription(
            name: "止めたやつ",
            originalAmount: 1_000,
            state: .paused,
            renewalDate: date(2026, 8, 28),
            startDate: date(2025, 1, 1)
        )

        XCTAssertEqual(mood(subscriptions: [paused]), .pleased)
    }
}
