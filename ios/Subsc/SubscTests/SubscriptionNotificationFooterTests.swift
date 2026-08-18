import XCTest
@testable import Subsc

/// 通知セクションのフッター文言のテストです。
///
/// **審査で「通知を許可しないと保存できない」と指摘された（2026-08-18 / Guideline 2.1(a)）** ため、
/// 保存を止めるのをやめ、代わりにこのフッターで「今は届かない」ことを伝えるようにしました。
@MainActor
final class SubscriptionNotificationFooterTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    /// 2026年8月20日（更新日）
    private var renewalDate: Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 20)) ?? .distantFuture
    }

    /// 2026年8月18日 12:00（現在）
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 18, hour: 12)) ?? .distantPast
    }

    func testNotificationsOffShowsOnlyTheBaseText() {
        let text = SubscriptionNotificationFooter.text(
            notificationsEnabled: false,
            permission: .denied,
            renewalDate: renewalDate,
            hour: 9,
            minute: 0,
            leadDays: [1],
            leadHours: [],
            now: now,
            calendar: calendar
        )

        // 通知を使わない設定なら、許可の有無は関係ない
        XCTAssertEqual(text, SubscriptionNotificationFooter.base)
    }

    func testAuthorizedAndInTimeShowsOnlyTheBaseText() {
        let text = SubscriptionNotificationFooter.text(
            notificationsEnabled: true,
            permission: .authorized,
            renewalDate: renewalDate,
            hour: 9,
            minute: 0,
            leadDays: [1],
            leadHours: [],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(text, SubscriptionNotificationFooter.base)
    }

    func testDeniedTellsThatNothingIsDeliveredForNow() {
        let text = SubscriptionNotificationFooter.text(
            notificationsEnabled: true,
            permission: .denied,
            renewalDate: renewalDate,
            hour: 9,
            minute: 0,
            leadDays: [1],
            leadHours: [],
            now: now,
            calendar: calendar
        )

        XCTAssertTrue(text.hasPrefix(SubscriptionNotificationFooter.base))
        XCTAssertTrue(text.contains("許可されていない"))
        // 一度断るとiOSはダイアログを出さないため、設定アプリへ誘導する
        XCTAssertTrue(text.contains("設定"))
        // 保存できないと誤解させない
        XCTAssertFalse(text.contains("保存"))
    }

    func testDeniedTakesPrecedenceOverTheTimingNotice() {
        // 通知タイミングが未選択（＝届かない）でも、許可が無いことの方が上位
        let text = SubscriptionNotificationFooter.text(
            notificationsEnabled: true,
            permission: .denied,
            renewalDate: renewalDate,
            hour: 9,
            minute: 0,
            leadDays: [],
            leadHours: [],
            now: now,
            calendar: calendar
        )

        XCTAssertTrue(text.contains("許可されていない"))
        XCTAssertFalse(text.contains("通知タイミングが選ばれていない"))
    }

    func testNotDeterminedDoesNotWarnBecauseTheDialogAppearsOnSave() {
        let text = SubscriptionNotificationFooter.text(
            notificationsEnabled: true,
            permission: .notDetermined,
            renewalDate: renewalDate,
            hour: 9,
            minute: 0,
            leadDays: [1],
            leadHours: [],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(text, SubscriptionNotificationFooter.base)
    }

    func testCheckingDoesNotWarnWhileTheStatusIsUnknown() {
        let text = SubscriptionNotificationFooter.text(
            notificationsEnabled: true,
            permission: .checking,
            renewalDate: renewalDate,
            hour: 9,
            minute: 0,
            leadDays: [1],
            leadHours: [],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(text, SubscriptionNotificationFooter.base)
    }

    func testNoLeadTimeSelectedStillWarnsWhenAuthorized() {
        let text = SubscriptionNotificationFooter.text(
            notificationsEnabled: true,
            permission: .authorized,
            renewalDate: renewalDate,
            hour: 9,
            minute: 0,
            leadDays: [],
            leadHours: [],
            now: now,
            calendar: calendar
        )

        XCTAssertTrue(text.contains("通知タイミングが選ばれていない"))
    }

    func testPassedTimeWarnsThatTheNextOneIsMissed() {
        // 更新日が今日で、前日9:00の通知はもう過ぎている
        let renewalToday = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 18)
        ) ?? .distantFuture
        let text = SubscriptionNotificationFooter.text(
            notificationsEnabled: true,
            permission: .authorized,
            renewalDate: renewalToday,
            hour: 9,
            minute: 0,
            leadDays: [1],
            leadHours: [],
            now: now,
            calendar: calendar
        )

        XCTAssertTrue(text.contains("直近の1回は届きません"))
    }
}
