import XCTest
@testable import Subsc

/// 年月を選ぶホイールに出す**年の範囲**のテストです。
///
/// **固定の範囲（2000〜2100など）にしません。** 選べる年が実際の登録と合っていないと、
/// ほとんど中身の無い年を延々と回すことになります。
final class CalendarMonthPickerRangeTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt
        return calendar
    }

    private let now = DateComponents(
        calendar: {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt
            return calendar
        }(),
        year: 2026,
        month: 8,
        day: 11
    ).date ?? .distantPast

    /// 登録が1件も無ければ、**今年の前後1年**だけを出します。
    func testEmptyDataFallsBackToThisYear() {
        let range = CalendarMonthPickerRange.years(from: [], now: now, calendar: calendar)

        XCTAssertEqual(range, Array(2025...2027))
    }

    /// 期日が過去だけでも、**今年までは選べます**。
    /// 今年が抜けると「今日へ戻る」で行ける月をホイールから選べません。
    func testPastOnlyDataStillReachesThisYear() {
        let dates = [date(2023, 4, 1), date(2024, 9, 30)]

        let range = CalendarMonthPickerRange.years(from: dates, now: now, calendar: calendar)

        XCTAssertEqual(range.first, 2022)
        XCTAssertEqual(range.last, 2027)
        XCTAssertTrue(range.contains(2026))
    }

    /// 期日が未来だけでも、今年から出します。
    func testFutureOnlyDataStillStartsFromThisYear() {
        let dates = [date(2030, 1, 5)]

        let range = CalendarMonthPickerRange.years(from: dates, now: now, calendar: calendar)

        XCTAssertEqual(range.first, 2025)
        XCTAssertEqual(range.last, 2031)
    }

    /// 前後に1年ずつ余裕を足します。**端の年に着いたときに、その先が無いと行き止まりに見えます。**
    func testRangeAddsOneYearOfHeadroomOnBothEnds() {
        let dates = [date(2026, 1, 1)]

        let range = CalendarMonthPickerRange.years(from: dates, now: now, calendar: calendar)

        XCTAssertEqual(range, Array(2025...2027))
    }

    /// 年は昇順で、重複しません。ホイールに同じ年が二度出ると選べなくなります。
    func testYearsAreSortedAndUnique() {
        let dates = [date(2028, 3, 1), date(2024, 3, 1), date(2028, 7, 1)]

        let range = CalendarMonthPickerRange.years(from: dates, now: now, calendar: calendar)

        XCTAssertEqual(range, range.sorted())
        XCTAssertEqual(range.count, Set(range).count)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateComponents(calendar: calendar, year: year, month: month, day: day).date ?? .distantPast
    }
}
