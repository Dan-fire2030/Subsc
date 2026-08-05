import XCTest
@testable import Subsc

/// 相棒の黒猫が、どの状態で座るかの判定です。
///
/// **実行日に依存させないため**、`Calendar(identifier: .gregorian)` と固定日付を使います。
final class CatMoodTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    /// 月の途中（8月10日）。月末まで日があり、催促の条件には掛かりません。
    private func midMonth() -> Date {
        DateComponents(calendar: calendar, year: 2026, month: 8, day: 10).date!
    }

    /// 月末が近い日（8月28日）。
    private func nearMonthEnd() -> Date {
        DateComponents(calendar: calendar, year: 2026, month: 8, day: 28).date!
    }

    private func mood(
        registrationCount: Int = 5,
        monthlyTotal: Double = 50_000,
        recentAverage: Double? = 50_000,
        hasUpcomingLargeCharge: Bool = false,
        hasUnenteredVariableCost: Bool = false,
        now: Date? = nil
    ) -> CatMood {
        CatMood.decide(
            registrationCount: registrationCount,
            monthlyTotal: monthlyTotal,
            recentAverage: recentAverage,
            hasUpcomingLargeCharge: hasUpcomingLargeCharge,
            hasUnenteredVariableCost: hasUnenteredVariableCost,
            now: now ?? midMonth(),
            calendar: calendar
        )
    }

    // MARK: - それぞれの状態

    func testNothingSpecialIsCalm() {
        XCTAssertEqual(mood(), .calm)
    }

    func testNoRegistrationsGuides() {
        XCTAssertEqual(mood(registrationCount: 0), .guiding)
    }

    func testSpendingWellOverTheAverageWorries() {
        XCTAssertEqual(mood(monthlyTotal: 70_000, recentAverage: 50_000), .worried)
    }

    func testSpendingWellUnderTheAveragePleases() {
        XCTAssertEqual(mood(monthlyTotal: 30_000, recentAverage: 50_000), .pleased)
    }

    func testUpcomingLargeChargeWatches() {
        XCTAssertEqual(mood(hasUpcomingLargeCharge: true), .watching)
    }

    func testUnenteredVariableCostNearMonthEndNudges() {
        XCTAssertEqual(
            mood(hasUnenteredVariableCost: true, now: nearMonthEnd()),
            .nudging
        )
    }

    // MARK: - 催促は月末が近いときだけ

    /// **月の途中では催促しません。** まだ入力する時間があるうちに急かすと、
    /// 毎日出続けて意味を失います。
    func testUnenteredVariableCostMidMonthDoesNotNudge() {
        XCTAssertEqual(mood(hasUnenteredVariableCost: true, now: midMonth()), .calm)
    }

    // MARK: - 優先順位

    /// 費目が0件なら、ほかの条件が立っていても案内を出します。まだ何も無い人に
    /// 支出の増減を伝えても意味がないためです。
    func testGuidingWinsOverEverything() {
        XCTAssertEqual(
            mood(
                registrationCount: 0,
                monthlyTotal: 70_000,
                recentAverage: 50_000,
                hasUpcomingLargeCharge: true,
                hasUnenteredVariableCost: true,
                now: nearMonthEnd()
            ),
            .guiding
        )
    }

    /// 催促は見張るより優先します。**利用者の行動を求めるほうが先**だからです。
    func testNudgingWinsOverWatching() {
        XCTAssertEqual(
            mood(hasUpcomingLargeCharge: true, hasUnenteredVariableCost: true, now: nearMonthEnd()),
            .nudging
        )
    }

    /// 見張るは、支出の増減より優先します。これから出ていく額のほうが行動につながります。
    func testWatchingWinsOverWorried() {
        XCTAssertEqual(
            mood(monthlyTotal: 70_000, recentAverage: 50_000, hasUpcomingLargeCharge: true),
            .watching
        )
    }

    // MARK: - 境目

    /// わずかな増減で表情が動くと落ち着かないため、**15%の幅を持たせます**。
    func testSmallDifferencesFromTheAverageStayCalm() {
        XCTAssertEqual(mood(monthlyTotal: 55_000, recentAverage: 50_000), .calm)
        XCTAssertEqual(mood(monthlyTotal: 45_000, recentAverage: 50_000), .calm)
    }

    func testExactlyAtTheThresholdStaysCalm() {
        XCTAssertEqual(mood(monthlyTotal: 57_500, recentAverage: 50_000), .calm)
        XCTAssertEqual(mood(monthlyTotal: 42_500, recentAverage: 50_000), .calm)
    }

    /// 比較できる過去が無い月（初月）は、増減を語らず平常にします。
    func testWithoutAnAverageStaysCalm() {
        XCTAssertEqual(mood(monthlyTotal: 70_000, recentAverage: nil), .calm)
    }

    /// 過去の平均が0円のとき、割り算で判定すると必ず「増えた」になります。
    /// 比較対象として意味がないので平常に倒します。
    func testZeroAverageStaysCalm() {
        XCTAssertEqual(mood(monthlyTotal: 70_000, recentAverage: 0), .calm)
    }
}
