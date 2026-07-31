import Foundation

/// 変動費の「今月の金額をまだ記録していない」リマインドを組み立てます。
///
/// 記録が無いまま月が変わると、レポートは直近の実績で見込むしかなくなります。
/// 見込みのままにしないため、**月末に一度だけ**入力を促します。
///
/// 先の月ぶんまで予約しておくのは、アプリを開かない月があっても通知が届くようにするためです。
/// 実績が入力されると、その月のリマインドは再スケジュール時に計画から外れて取り消されます。
enum ReminderPlanner {
    /// 何ヶ月先まで予約しておくか。長くすると予約枠を食い、更新日通知を圧迫します。
    static let monthsAhead = 3

    static func plannedReminders(
        subscriptions: [Subscription],
        now: Date,
        limit: Int,
        calendar: Calendar = .current
    ) -> [NotificationService.PlannedNotification] {
        guard limit > 0 else { return [] }

        let targets = subscriptions.filter {
            $0.hasVariableAmount && $0.state == .active && $0.notificationsEnabled
        }
        guard !targets.isEmpty else { return [] }

        let planned = targets.flatMap { subscription in
            periodStarts(from: now, calendar: calendar).compactMap {
                reminder(for: subscription, monthStart: $0, now: now, calendar: calendar)
            }
        }

        return planned
            .sorted { $0.date == $1.date ? $0.identifier < $1.identifier : $0.date < $1.date }
            .prefix(limit)
            .map { $0 }
    }

    /// 今月から `monthsAhead` ヶ月ぶんの、月初の日付です。
    private static func periodStarts(from now: Date, calendar: Calendar) -> [Date] {
        guard let thisMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) else {
            return []
        }
        return (0..<monthsAhead).compactMap {
            calendar.date(byAdding: .month, value: $0, to: thisMonth)
        }
    }

    private static func reminder(
        for subscription: Subscription,
        monthStart: Date,
        now: Date,
        calendar: Calendar
    ) -> NotificationService.PlannedNotification? {
        let periodKey = AmountEntry.periodKey(for: monthStart, calendar: calendar)
        guard !AmountEntryStore.hasRecord(on: subscription, periodKey: periodKey) else {
            return nil
        }
        guard let fireDate = lastDayOfMonth(
            monthStart,
            hour: subscription.notificationHour,
            minute: subscription.notificationMinute,
            calendar: calendar
        ) else {
            return nil
        }
        // 月末の通知時刻をすでに過ぎている月は、いま予約しても届きません。
        guard fireDate > now else { return nil }

        return NotificationService.PlannedNotification(
            clientID: subscription.clientID,
            identifier: NotificationIdentifier.reminder(
                clientID: subscription.clientID,
                periodKey: periodKey
            ),
            date: fireDate,
            title: "\(subscription.name)の金額を記録しましょう",
            body: "\(periodKey / 100)年\(periodKey % 100)月ぶんの金額がまだ記録されていません。"
        )
    }

    /// その月の末日の、指定時刻です。30日までの月や2月でも末日になります。
    private static func lastDayOfMonth(
        _ monthStart: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date? {
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return nil
        }
        var components = calendar.dateComponents([.year, .month], from: monthStart)
        components.day = dayRange.upperBound - 1
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)
    }
}
