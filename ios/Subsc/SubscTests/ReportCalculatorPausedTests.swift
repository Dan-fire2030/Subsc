import XCTest
@testable import Subsc

/// 停止した費目を、過去のレポートから消さないことのテストです。
///
/// **停止は「今」の状態であって、過去の事実ではありません。**
/// 過ぎ去った月からも消すと、実際に払っていた記録まで無かったことになり、
/// あとから見返した合計が勝手に変わります。
final class ReportCalculatorPausedTests: XCTestCase {
    private enum Fixture {
        static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt
            return calendar
        }

        /// 「今日」を固定します。実行日で結果が変わらないようにするためです。
        static let now = DateComponents(
            calendar: calendar,
            year: 2026,
            month: 8,
            day: 15
        ).date ?? .distantPast
    }

    // MARK: - 過去の期間

    func testPausedSubscriptionStaysInAPastMonth() {
        let subscription = makePausedSubscription()

        let report = ReportCalculator.report(
            subscriptions: [subscription],
            period: .month,
            cursor: date(2026, 5, 10),
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(report.entries.map(\.name), ["動画"])
        XCTAssertEqual(report.total, 1_490, accuracy: 0.5)
    }

    func testPausedSubscriptionStaysInAPastYear() {
        let subscription = makePausedSubscription()

        let report = ReportCalculator.report(
            subscriptions: [subscription],
            period: .year,
            cursor: date(2025, 6, 10),
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(report.entries.count, 1)
        XCTAssertGreaterThan(report.total, 0)
    }

    // MARK: - 現在と未来の期間

    /// **今月からは消えます。** もう払っていない額を「今月の支出」に残しません。
    func testPausedSubscriptionIsExcludedFromTheCurrentMonth() {
        let subscription = makePausedSubscription()

        let report = ReportCalculator.report(
            subscriptions: [subscription],
            period: .month,
            cursor: Fixture.now,
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertTrue(report.entries.isEmpty)
        XCTAssertEqual(report.total, 0)
    }

    func testPausedSubscriptionIsExcludedFromAFutureMonth() {
        let subscription = makePausedSubscription()

        let report = ReportCalculator.report(
            subscriptions: [subscription],
            period: .month,
            cursor: date(2026, 11, 10),
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertTrue(report.entries.isEmpty)
    }

    /// 月末に停止しても、その月は現在の期間なので除外されます。境界の確認です。
    func testTheMonthContainingTodayIsNotTreatedAsPast() {
        let subscription = makePausedSubscription()

        let lastDayOfMonth = ReportCalculator.report(
            subscriptions: [subscription],
            period: .month,
            cursor: date(2026, 8, 31),
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertTrue(lastDayOfMonth.entries.isEmpty)
    }

    /// 前月は過去なので残ります。上のテストと対で境界を挟みます。
    func testThePreviousMonthIsTreatedAsPast() {
        let subscription = makePausedSubscription()

        let report = ReportCalculator.report(
            subscriptions: [subscription],
            period: .month,
            cursor: date(2026, 7, 31),
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(report.entries.count, 1)
    }

    // MARK: - 利用中は従来どおり

    func testActiveSubscriptionIsUnaffected() {
        let subscription = Subscription(
            name: "動画",
            originalAmount: 1_490,
            renewalDate: date(2026, 8, 20)
        )

        let past = ReportCalculator.report(
            subscriptions: [subscription],
            period: .month,
            cursor: date(2026, 5, 10),
            now: Fixture.now,
            calendar: Fixture.calendar
        )
        let current = ReportCalculator.report(
            subscriptions: [subscription],
            period: .month,
            cursor: Fixture.now,
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertEqual(past.entries.count, 1)
        XCTAssertEqual(current.entries.count, 1)
    }

    /// 契約期間の判定は停止と別です。開始前の月には、停止していても出しません。
    func testAPausedSubscriptionStillRespectsItsStartDate() {
        let subscription = makePausedSubscription()
        subscription.startDate = date(2026, 6, 1)

        let beforeStart = ReportCalculator.report(
            subscriptions: [subscription],
            period: .month,
            cursor: date(2026, 5, 10),
            now: Fixture.now,
            calendar: Fixture.calendar
        )
        let afterStart = ReportCalculator.report(
            subscriptions: [subscription],
            period: .month,
            cursor: date(2026, 6, 10),
            now: Fixture.now,
            calendar: Fixture.calendar
        )

        XCTAssertTrue(beforeStart.entries.isEmpty)
        XCTAssertEqual(afterStart.entries.count, 1)
    }

    // MARK: - 補助

    private func makePausedSubscription() -> Subscription {
        let subscription = Subscription(
            name: "動画",
            originalAmount: 1_490,
            renewalDate: date(2026, 8, 20)
        )
        subscription.state = .paused
        return subscription
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Fixture.calendar.date(from: components) ?? .distantPast
    }
}
