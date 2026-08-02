import XCTest
@testable import Subsc

/// 変動費がレポートにどう集計されるかのテストです。
/// 実行日に依存させないため、固定のカレンダーと日付を使います。
final class ReportCalculatorVariableAmountTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    private func makeUtility(entries: [(Int, Int, Double)]) -> Subscription {
        let subscription = Subscription(
            name: "電気代",
            costType: .utility,
            hasVariableAmount: true,
            originalAmount: 0,
            renewalDate: date(2026, 7, 25)
        )
        subscription.amountEntries = entries.map {
            AmountEntry(year: $0.0, month: $0.1, amount: $0.2)
        }
        return subscription
    }

    func testMonthlyReportUsesTheRecordForThatMonth() {
        let electricity = makeUtility(entries: [(2026, 6, 6500), (2026, 7, 8200)])

        let report = ReportCalculator.report(
            subscriptions: [electricity],
            period: .month,
            cursor: date(2026, 7, 15),
            calendar: calendar
        )

        XCTAssertEqual(report.total, 8200)
        XCTAssertEqual(report.entries.first?.isEstimated, false)
    }

    func testAMonthWithoutARecordIsMarkedAsEstimated() {
        let electricity = makeUtility(entries: [(2026, 6, 6500)])

        let report = ReportCalculator.report(
            subscriptions: [electricity],
            period: .month,
            cursor: date(2026, 7, 15),
            calendar: calendar
        )

        XCTAssertEqual(report.total, 6500)
        XCTAssertEqual(report.entries.first?.isEstimated, true)
    }

    func testAVariableCostWithoutAnyRecordIsLeftOutOfTheReport() {
        let electricity = makeUtility(entries: [])

        let report = ReportCalculator.report(
            subscriptions: [electricity],
            period: .month,
            cursor: date(2026, 7, 15),
            calendar: calendar
        )

        XCTAssertEqual(report.total, 0)
        XCTAssertTrue(report.entries.isEmpty)
    }

    func testYearlyReportSumsEachMonthSeparatelyInsteadOfMultiplying() {
        // 1月〜3月だけ実績があり、4月以降は3月の額で見込む年
        let electricity = makeUtility(entries: [
            (2026, 1, 10000),
            (2026, 2, 9000),
            (2026, 3, 5000)
        ])

        let report = ReportCalculator.report(
            subscriptions: [electricity],
            period: .year,
            cursor: date(2026, 7, 15),
            calendar: calendar
        )

        // 10000 + 9000 + 5000 + 5000 × 9ヶ月
        XCTAssertEqual(report.total, 69000)
        XCTAssertEqual(report.entries.first?.isEstimated, true)
    }

    func testYearlyReportOfAFullyRecordedYearIsNotMarkedAsEstimated() {
        let electricity = makeUtility(entries: (1...12).map { (2026, $0, 1000) })

        let report = ReportCalculator.report(
            subscriptions: [electricity],
            period: .year,
            cursor: date(2026, 7, 15),
            calendar: calendar
        )

        XCTAssertEqual(report.total, 12000)
        XCTAssertEqual(report.entries.first?.isEstimated, false)
    }

    func testFixedCostsAreStillReportedTheSameWayAndAreNeverEstimated() {
        let netflix = Subscription(
            name: "Netflix",
            originalAmount: 1490,
            renewalDate: date(2026, 7, 25)
        )

        let report = ReportCalculator.report(
            subscriptions: [netflix],
            period: .month,
            cursor: date(2026, 7, 15),
            calendar: calendar
        )

        XCTAssertEqual(report.total, 1490)
        XCTAssertEqual(report.entries.first?.isEstimated, false)
    }

    func testFixedAndVariableCostsAreTotalledTogether() {
        let netflix = Subscription(
            name: "Netflix",
            originalAmount: 1490,
            renewalDate: date(2026, 7, 25)
        )
        let electricity = makeUtility(entries: [(2026, 7, 8200)])

        let report = ReportCalculator.report(
            subscriptions: [netflix, electricity],
            period: .month,
            cursor: date(2026, 7, 15),
            calendar: calendar
        )

        XCTAssertEqual(report.total, 9690)
        XCTAssertEqual(report.entries.count, 2)
    }

    /// 停止した変動費は、**これからの月**からは消えます。もう払わないためです。
    func testPausedVariableCostsAreExcludedFromTheCurrentMonth() {
        let electricity = makeUtility(entries: [(2026, 7, 8200)])
        electricity.state = .paused

        let report = ReportCalculator.report(
            subscriptions: [electricity],
            period: .month,
            cursor: date(2026, 7, 15),
            now: date(2026, 7, 20),
            calendar: calendar
        )

        XCTAssertTrue(report.entries.isEmpty)
    }

    /// **過去の月に記録した実績は、停止しても残ります。**
    ///
    /// 以前はここも消えており、停止した瞬間に「先月いくら払ったか」が変わっていました。
    /// 8,200円は実際に払った額なので、あとから無かったことにはできません。
    func testPausedVariableCostsKeepTheirPastRecords() {
        let electricity = makeUtility(entries: [(2026, 7, 8200)])
        electricity.state = .paused

        let report = ReportCalculator.report(
            subscriptions: [electricity],
            period: .month,
            cursor: date(2026, 7, 15),
            now: date(2026, 9, 1),
            calendar: calendar
        )

        XCTAssertEqual(report.total, 8200)
        XCTAssertEqual(report.entries.first?.isEstimated, false)
    }
}
