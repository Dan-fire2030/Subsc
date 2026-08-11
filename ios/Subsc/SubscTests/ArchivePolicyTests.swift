import XCTest
@testable import Subsc

/// アーカイブの期限まわりの判断のテストです。
///
/// **判断をビューに置きません。** 「あと何日か」と「もう消してよいか」は
/// 一覧・詳細・自動削除の3箇所から必要になり、写すと必ず食い違います。
final class ArchivePolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt
        return calendar
    }

    // MARK: - アーカイブ中かどうか

    /// `archivedAt` が無ければアーカイブしていません。
    func testNilMeansNotArchived() {
        XCTAssertFalse(ArchivePolicy.isArchived(nil))
        XCTAssertTrue(ArchivePolicy.isArchived(date(2026, 8, 1)))
    }

    // MARK: - 残り日数

    /// アーカイブした当日は30日残っています。
    func testTheDayOfArchivingHasTheFullRetention() {
        let remaining = ArchivePolicy.remainingDays(
            archivedAt: date(2026, 8, 11),
            now: date(2026, 8, 11),
            calendar: calendar
        )

        XCTAssertEqual(remaining, 30)
    }

    /// **時刻ではなく日付の境目で減ります。**
    /// 時刻で比べると、同じ日なのに「あと30日」と「あと29日」が混ざります。
    func testRemainingDaysChangeOnTheDayBoundaryNotTheClock() {
        let archivedAt = dateTime(2026, 8, 11, hour: 23, minute: 30)

        // 同じ日の朝（アーカイブより前の時刻）でも、同じ日なら30日のまま
        XCTAssertEqual(
            ArchivePolicy.remainingDays(
                archivedAt: archivedAt,
                now: dateTime(2026, 8, 11, hour: 1, minute: 0),
                calendar: calendar
            ),
            30
        )

        // 日付が変われば、わずか30分後でも1日減る
        XCTAssertEqual(
            ArchivePolicy.remainingDays(
                archivedAt: archivedAt,
                now: dateTime(2026, 8, 12, hour: 0, minute: 0),
                calendar: calendar
            ),
            29
        )
    }

    /// **30日ちょうどの日はまだ残ります。** 残り0日として出します。
    func testTheThirtiethDayStillRemains() {
        let remaining = ArchivePolicy.remainingDays(
            archivedAt: date(2026, 8, 11),
            now: date(2026, 9, 10),
            calendar: calendar
        )

        XCTAssertEqual(remaining, 0)
        XCTAssertFalse(
            ArchivePolicy.isExpired(
                archivedAt: date(2026, 8, 11),
                now: date(2026, 9, 10),
                calendar: calendar
            )
        )
    }

    /// **31日目で消えます。**
    func testTheThirtyFirstDayExpires() {
        XCTAssertTrue(
            ArchivePolicy.isExpired(
                archivedAt: date(2026, 8, 11),
                now: date(2026, 9, 11),
                calendar: calendar
            )
        )
    }

    /// 期限を過ぎたあとは、残り日数を0で止めます。負の数を画面へ出さないためです。
    func testRemainingDaysNeverGoNegative() {
        let remaining = ArchivePolicy.remainingDays(
            archivedAt: date(2026, 8, 11),
            now: date(2026, 12, 31),
            calendar: calendar
        )

        XCTAssertEqual(remaining, 0)
    }

    /// アーカイブしていなければ残り日数はありません。
    func testNotArchivedHasNoRemainingDays() {
        XCTAssertNil(
            ArchivePolicy.remainingDays(archivedAt: nil, now: date(2026, 8, 11), calendar: calendar)
        )
        XCTAssertFalse(
            ArchivePolicy.isExpired(archivedAt: nil, now: date(2026, 8, 11), calendar: calendar)
        )
    }

    // MARK: - 月またぎ・うるう年

    /// 月をまたいでも日数で数えます。
    func testCountingCrossesMonths() {
        // 1月31日にアーカイブ → 30日後は3月2日（2026年は平年）
        XCTAssertFalse(
            ArchivePolicy.isExpired(
                archivedAt: date(2026, 1, 31),
                now: date(2026, 3, 2),
                calendar: calendar
            )
        )
        XCTAssertTrue(
            ArchivePolicy.isExpired(
                archivedAt: date(2026, 1, 31),
                now: date(2026, 3, 3),
                calendar: calendar
            )
        )
    }

    /// うるう年の2月をまたいでも、日数の数え方は変わりません。
    func testLeapYearIsCountedInDays() {
        // 2028年はうるう年。1月31日 + 30日 = 3月1日
        XCTAssertFalse(
            ArchivePolicy.isExpired(
                archivedAt: date(2028, 1, 31),
                now: date(2028, 3, 1),
                calendar: calendar
            )
        )
        XCTAssertTrue(
            ArchivePolicy.isExpired(
                archivedAt: date(2028, 1, 31),
                now: date(2028, 3, 2),
                calendar: calendar
            )
        )
    }

    /// **期限が近いかの判定**です。行の色を変える鍵に使います。
    func testExpiringSoonIsTheLastSevenDays() {
        // 残り7日
        XCTAssertTrue(
            ArchivePolicy.isExpiringSoon(
                archivedAt: date(2026, 8, 11),
                now: date(2026, 9, 3),
                calendar: calendar
            )
        )
        // 残り8日
        XCTAssertFalse(
            ArchivePolicy.isExpiringSoon(
                archivedAt: date(2026, 8, 11),
                now: date(2026, 9, 2),
                calendar: calendar
            )
        )
    }

    // MARK: - 材料

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateComponents(calendar: calendar, year: year, month: month, day: day).date ?? .distantPast
    }

    private func dateTime(_ year: Int, _ month: Int, _ day: Int, hour: Int, minute: Int) -> Date {
        DateComponents(
            calendar: calendar,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ).date ?? .distantPast
    }
}
