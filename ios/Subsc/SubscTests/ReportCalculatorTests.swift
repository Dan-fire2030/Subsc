import XCTest
@testable import Subsc

final class ReportCalculatorTests: XCTestCase {
    func testMonthlyReportUsesMonthlyEquivalentForYearlyPlans() {
        let calendar = Calendar(identifier: .gregorian)
        let cursor = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let subscription = Subscription(
            name: "Yearly",
            originalAmount: 12_000,
            billingCycle: .yearly,
            renewalDate: cursor,
            startDate: cursor
        )

        let report = ReportCalculator.report(
            subscriptions: [subscription],
            period: .month,
            cursor: cursor,
            calendar: calendar
        )

        XCTAssertEqual(report.total, 1_000, accuracy: 0.001)
    }

    func testPausedPlansAreExcluded() {
        let subscription = Subscription(
            name: "Paused",
            originalAmount: 1_000,
            state: .paused,
            renewalDate: .now
        )

        let report = ReportCalculator.report(
            subscriptions: [subscription],
            period: .month,
            cursor: .now
        )

        XCTAssertEqual(report.total, 0)
        XCTAssertTrue(report.entries.isEmpty)
    }

    func testPeriodShiftMovesBySelectedUnit() {
        let calendar = Calendar.current
        let cursor = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let nextMonth = ReportCalculator.shifted(cursor, period: .month, by: 1)
        let nextYear = ReportCalculator.shifted(cursor, period: .year, by: 1)

        XCTAssertEqual(calendar.component(.month, from: nextMonth), 8)
        XCTAssertEqual(calendar.component(.year, from: nextYear), 2027)
    }

    func testDollarPlanUsesStoredUsdJpyRate() {
        let subscription = Subscription(
            name: "Dollar",
            originalAmount: 10,
            exchangeRate: 150,
            currency: .usd,
            renewalDate: .now
        )

        XCTAssertEqual(subscription.yenAmount, 1_500, accuracy: 0.001)
        XCTAssertEqual(subscription.monthlyYen, 1_500, accuracy: 0.001)
    }

    func testNewSubscriptionDefaultsToOneDayNotificationOnly() {
        let subscription = Subscription(
            name: "Default notification",
            originalAmount: 1_000,
            renewalDate: .now
        )

        XCTAssertEqual(subscription.leadDays, [1])
        XCTAssertTrue(subscription.leadHours.isEmpty)
    }

    func testAnnualReportCountsTheStartingMonthThroughYearEnd() {
        let calendar = Calendar(identifier: .gregorian)
        let cursor = calendar.date(from: DateComponents(year: 2026, month: 12, day: 20))!
        let startDate = calendar.date(from: DateComponents(year: 2026, month: 12, day: 15))!
        let subscription = Subscription(
            name: "December plan",
            originalAmount: 1_000,
            renewalDate: startDate,
            startDate: startDate
        )

        let report = ReportCalculator.report(
            subscriptions: [subscription],
            period: .year,
            cursor: cursor,
            calendar: calendar
        )

        XCTAssertEqual(report.total, 1_000, accuracy: 0.001)
    }

    func testAnnualReportProratesYearlyPlanByActiveMonths() {
        let calendar = Calendar(identifier: .gregorian)
        let cursor = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let startDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15))!
        let subscription = Subscription(
            name: "Half-year plan",
            originalAmount: 12_000,
            billingCycle: .yearly,
            renewalDate: startDate,
            startDate: startDate
        )

        let report = ReportCalculator.report(
            subscriptions: [subscription],
            period: .year,
            cursor: cursor,
            calendar: calendar
        )

        XCTAssertEqual(report.total, 6_000, accuracy: 0.001)
    }

    func testMonthlyRenewalKeepsOriginalDayWhenPossible() {
        let calendar = Calendar(identifier: .gregorian)
        let january31 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!
        let march1 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let subscription = Subscription(
            name: "Month end",
            originalAmount: 1_000,
            renewalDate: january31
        )

        let next = subscription.nextRenewalDate(onOrAfter: march1, calendar: calendar)

        XCTAssertEqual(
            next,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 31))
        )

        let upcoming = subscription.upcomingRenewalDates(
            onOrAfter: calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!,
            limit: 3,
            calendar: calendar
        )
        XCTAssertEqual(
            upcoming,
            [
                calendar.date(from: DateComponents(year: 2026, month: 2, day: 28))!,
                calendar.date(from: DateComponents(year: 2026, month: 3, day: 31))!,
                calendar.date(from: DateComponents(year: 2026, month: 4, day: 30))!
            ]
        )
    }

    func testRenewalStopsAfterContractEndDate() {
        let calendar = Calendar(identifier: .gregorian)
        let renewal = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let endDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 28))!
        let march = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let subscription = Subscription(
            name: "Ended",
            originalAmount: 1_000,
            renewalDate: renewal,
            endDate: endDate
        )

        XCTAssertNil(subscription.nextRenewalDate(onOrAfter: march, calendar: calendar))
    }
}
