import XCTest
@testable import Subsc

/// 「あと何日か」の文言を確かめます。
///
/// **この計算はビューの中に埋まっていて、実行日を注入できませんでした**（2026-08-08のレビュー）。
/// 境目が実行日で変わるため、固定日付で押さえておかないと壊れても気づけません。
final class RelativeDueLabelTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testSameDayIsCalledToday() {
        let label = RelativeDueLabel.text(
            for: date(2026, 8, 8, hour: 23),
            now: date(2026, 8, 8, hour: 1),
            calendar: calendar
        )
        XCTAssertEqual(label, "今日", "同じ日なら時刻が離れていても「今日」")
    }

    func testFutureDatesCountRemainingDays() {
        let label = RelativeDueLabel.text(
            for: date(2026, 8, 11),
            now: date(2026, 8, 8),
            calendar: calendar
        )
        XCTAssertEqual(label, "あと3日")
    }

    /// **時刻ではなく日付の差で数えます。** 23時に見たときの「明日の0時」は
    /// 1時間後ですが、利用者にとっては「あと1日」です。
    func testCountingIgnoresTheTimeOfDay() {
        let label = RelativeDueLabel.text(
            for: date(2026, 8, 9, hour: 0),
            now: date(2026, 8, 8, hour: 23),
            calendar: calendar
        )
        XCTAssertEqual(label, "あと1日", "1時間後でも日付が変われば「あと1日」")
    }

    func testPastDatesAreCalledOverdue() {
        let label = RelativeDueLabel.text(
            for: date(2026, 8, 7),
            now: date(2026, 8, 8),
            calendar: calendar
        )
        XCTAssertEqual(label, "期日超過")
    }

    /// 月をまたいでも日数で数えます。月の長さに引きずられません。
    func testCountingCrossesMonthBoundaries() {
        let label = RelativeDueLabel.text(
            for: date(2026, 9, 2),
            now: date(2026, 8, 31),
            calendar: calendar
        )
        XCTAssertEqual(label, "あと2日")
    }

    func testMissingDueDateProducesNoLabel() {
        let label = RelativeDueLabel.text(for: nil, now: date(2026, 8, 8), calendar: calendar)
        XCTAssertEqual(label, "", "期日が無ければ何も書かない")
    }
}
