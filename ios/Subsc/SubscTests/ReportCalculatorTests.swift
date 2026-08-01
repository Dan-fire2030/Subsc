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

    func testReportEntryIncludesSubscriptionCostType() throws {
        let calendar = Calendar(identifier: .gregorian)
        let cursor = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let subscription = Subscription(
            name: "電気",
            costType: .utility,
            originalAmount: 8_000,
            renewalDate: cursor,
            startDate: cursor
        )

        let report = ReportCalculator.report(
            subscriptions: [subscription],
            period: .month,
            cursor: cursor,
            calendar: calendar
        )

        XCTAssertEqual(try XCTUnwrap(report.entries.first).costType, .utility)
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

    func testMonthlyReportIncludesCostStartingOnFirstDay() {
        let calendar = Calendar(identifier: .gregorian)
        let julyFirst = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let subscription = Subscription(
            name: "期間初日",
            originalAmount: 1_000,
            renewalDate: julyFirst,
            startDate: julyFirst
        )

        let report = ReportCalculator.report(
            subscriptions: [subscription],
            period: .month,
            cursor: julyFirst,
            calendar: calendar
        )

        XCTAssertEqual(report.entries.map(\.name), ["期間初日"])
        XCTAssertEqual(report.total, 1_000, accuracy: 0.001)
    }

    func testMonthlyReportUsesExclusivePeriodEndForStartDate() {
        let calendar = Calendar(identifier: .gregorian)
        let julyFirst = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let julyLast = calendar.date(from: DateComponents(year: 2026, month: 7, day: 31))!
        let augustFirst = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
        let augustSecond = calendar.date(from: DateComponents(year: 2026, month: 8, day: 2))!
        let subscriptions = [
            Subscription(name: "終端1日前", originalAmount: 1_000, renewalDate: julyLast, startDate: julyLast),
            Subscription(name: "終端ちょうど", originalAmount: 1_000, renewalDate: augustFirst, startDate: augustFirst),
            Subscription(name: "終端1日後", originalAmount: 1_000, renewalDate: augustSecond, startDate: augustSecond)
        ]

        let julyReport = ReportCalculator.report(
            subscriptions: subscriptions,
            period: .month,
            cursor: julyFirst,
            calendar: calendar
        )
        let augustReport = ReportCalculator.report(
            subscriptions: subscriptions,
            period: .month,
            cursor: augustFirst,
            calendar: calendar
        )

        XCTAssertEqual(Set(julyReport.entries.map(\.name)), Set(["終端1日前"]))
        XCTAssertEqual(
            Set(augustReport.entries.map(\.name)),
            Set(["終端1日前", "終端ちょうど", "終端1日後"])
        )
        XCTAssertEqual(julyReport.total, 1_000, accuracy: 0.001)
        XCTAssertEqual(augustReport.total, 3_000, accuracy: 0.001)
    }

    func testAnnualReportIncludesCostStartingOnFirstDay() {
        let calendar = Calendar(identifier: .gregorian)
        let januaryFirst = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let subscription = Subscription(
            name: "期間初日",
            originalAmount: 1_000,
            renewalDate: januaryFirst,
            startDate: januaryFirst
        )

        let report = ReportCalculator.report(
            subscriptions: [subscription],
            period: .year,
            cursor: januaryFirst,
            calendar: calendar
        )

        XCTAssertEqual(report.entries.map(\.name), ["期間初日"])
        XCTAssertEqual(report.total, 12_000, accuracy: 0.001)
    }

    func testAnnualReportUsesExclusivePeriodEndForStartDate() {
        let calendar = Calendar(identifier: .gregorian)
        let januaryFirst2026 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let decemberLast = calendar.date(from: DateComponents(year: 2026, month: 12, day: 31))!
        let januaryFirst2027 = calendar.date(from: DateComponents(year: 2027, month: 1, day: 1))!
        let januarySecond2027 = calendar.date(from: DateComponents(year: 2027, month: 1, day: 2))!
        let subscriptions = [
            Subscription(name: "終端1日前", originalAmount: 1_000, renewalDate: decemberLast, startDate: decemberLast),
            Subscription(name: "終端ちょうど", originalAmount: 1_000, renewalDate: januaryFirst2027, startDate: januaryFirst2027),
            Subscription(name: "終端1日後", originalAmount: 1_000, renewalDate: januarySecond2027, startDate: januarySecond2027)
        ]

        let report2026 = ReportCalculator.report(
            subscriptions: subscriptions,
            period: .year,
            cursor: januaryFirst2026,
            calendar: calendar
        )
        let report2027 = ReportCalculator.report(
            subscriptions: subscriptions,
            period: .year,
            cursor: januaryFirst2027,
            calendar: calendar
        )

        XCTAssertEqual(Set(report2026.entries.map(\.name)), Set(["終端1日前"]))
        XCTAssertEqual(
            Set(report2027.entries.map(\.name)),
            Set(["終端1日前", "終端ちょうど", "終端1日後"])
        )
        XCTAssertEqual(report2026.total, 1_000, accuracy: 0.001)
        XCTAssertEqual(report2027.total, 36_000, accuracy: 0.001)
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

    func testAnyDayOfTheReferenceMonthCountsAsTheCurrentMonth() {
        let calendar = Calendar(identifier: .gregorian)
        let reference = calendar.date(from: DateComponents(year: 2026, month: 7, day: 28))!
        let firstOfMonth = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!

        XCTAssertTrue(
            ReportCalculator.isCurrentPeriod(
                firstOfMonth,
                period: .month,
                reference: reference,
                calendar: calendar
            )
        )
    }

    func testAnotherMonthIsNotTheCurrentMonth() {
        let calendar = Calendar(identifier: .gregorian)
        let reference = calendar.date(from: DateComponents(year: 2026, month: 7, day: 28))!
        let june = calendar.date(from: DateComponents(year: 2026, month: 6, day: 28))!

        XCTAssertFalse(
            ReportCalculator.isCurrentPeriod(
                june,
                period: .month,
                reference: reference,
                calendar: calendar
            )
        )
    }

    func testTheSameMonthInAnotherYearIsNotTheCurrentMonth() {
        let calendar = Calendar(identifier: .gregorian)
        let reference = calendar.date(from: DateComponents(year: 2026, month: 7, day: 28))!
        let lastYear = calendar.date(from: DateComponents(year: 2025, month: 7, day: 28))!

        XCTAssertFalse(
            ReportCalculator.isCurrentPeriod(
                lastYear,
                period: .month,
                reference: reference,
                calendar: calendar
            )
        )
    }

    func testAnyMonthOfTheReferenceYearCountsAsTheCurrentYear() {
        let calendar = Calendar(identifier: .gregorian)
        let reference = calendar.date(from: DateComponents(year: 2026, month: 7, day: 28))!
        let january = calendar.date(from: DateComponents(year: 2026, month: 1, day: 4))!

        XCTAssertTrue(
            ReportCalculator.isCurrentPeriod(
                january,
                period: .year,
                reference: reference,
                calendar: calendar
            )
        )
    }

    func testAnotherYearIsNotTheCurrentYear() {
        let calendar = Calendar(identifier: .gregorian)
        let reference = calendar.date(from: DateComponents(year: 2026, month: 7, day: 28))!
        let lastYear = calendar.date(from: DateComponents(year: 2025, month: 12, day: 31))!

        XCTAssertFalse(
            ReportCalculator.isCurrentPeriod(
                lastYear,
                period: .year,
                reference: reference,
                calendar: calendar
            )
        )
    }
}
