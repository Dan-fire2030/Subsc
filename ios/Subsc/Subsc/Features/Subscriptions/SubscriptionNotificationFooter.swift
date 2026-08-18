import Foundation

/// 通知セクションのフッター文言です。
///
/// **文言の判断をビューの状態から切り離しています。** 「届かない条件」が3つ（許可なし・
/// タイミング未選択・時刻超過）あり、どれを優先して伝えるかを画面の中で組み立てていると
/// テストで確かめられないためです。
@MainActor
enum SubscriptionNotificationFooter {
    static let base = "iOSのローカル通知として、アプリを閉じている時も配信されます。"

    /// 通知セクションの説明文を組み立てます。
    ///
    /// **許可されていないことを最優先で伝えます。** 許可が無ければどの設定でも1件も届かず、
    /// 「通知タイミングを見直してください」と案内すると原因と無関係な操作へ誘導するためです。
    ///
    /// **保存できるかどうかとは無関係です。** 以前は通知が許可されないと保存を止めていましたが、
    /// **審査で「通知を許可しないと項目を保存できない」と指摘された**（2026-08-18 /
    /// Guideline 2.1(a) Performance - App Completeness）ため、保存は常に通します。
    /// 通知が届かないことは、この文言だけで伝えます。
    static func text(
        notificationsEnabled: Bool,
        permission: NotificationPermission,
        renewalDate: Date,
        hour: Int,
        minute: Int,
        leadDays: [Int],
        leadHours: [Int],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        guard notificationsEnabled else { return base }

        if permission == .denied {
            return """
                \(base)

                ただし、iOSで通知が許可されていないため今は届きません。\
                設定アプリの「通知」から許可すると、この設定のまま届くようになります。
                """
        }

        guard !NotificationService.hasNotifiableTime(
            renewalDate: renewalDate,
            hour: hour,
            minute: minute,
            leadDays: leadDays,
            leadHours: leadHours,
            now: now,
            calendar: calendar
        ) else { return base }

        if leadDays.isEmpty, leadHours.isEmpty {
            return "\(base)\n\n通知タイミングが選ばれていないため、通知は届きません。"
        }
        return """
            \(base)

            この設定では、次の更新までに通知の時刻が過ぎているため、直近の1回は届きません。\
            通知タイミングを早めるか、通知時刻を先にしてください。次の更新以降は届きます。
            """
    }
}
