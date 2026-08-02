import Foundation
import UserNotifications

@MainActor
enum NotificationService {
    private static let maximumPendingRequests = 64
    private static let renewalCyclesPerSubscription = 12
    /// 月末リマインドに割り当てる予約枠です。
    /// iOSの予約数には上限があるため、更新日通知を圧迫しないように取り分を決めています。
    private static let reminderBudget = 16

    struct SyncResult: Equatable {
        let scheduled: Int
        let failed: Int
    }

    struct PlannedNotification: Equatable {
        let clientID: String
        let identifier: String
        let date: Date
        let title: String
        let body: String
        /// 通知に並べるボタンの組です。既定の nil はボタンなしを意味します。
        let categoryIdentifier: String?

        init(
            clientID: String,
            identifier: String,
            date: Date,
            title: String,
            body: String,
            categoryIdentifier: String? = nil
        ) {
            self.clientID = clientID
            self.identifier = identifier
            self.date = date
            self.title = title
            self.body = body
            self.categoryIdentifier = categoryIdentifier
        }
    }

    /// ローンの返済日通知に割り当てる予約枠です。
    private static let loanBudget = 12

    /// 通知に並べるボタンを登録します。**予約より先に済ませないとボタンが出ません。**
    static func registerCategories() {
        let actions = LoanNotificationAction.allCases.map {
            UNNotificationAction(identifier: $0.rawValue, title: $0.title, options: [])
        }
        let category = UNNotificationCategory(
            identifier: LoanNotificationAction.categoryIdentifier,
            actions: actions,
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    static func reschedule(for subscription: Subscription) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard !Task.isCancelled else { return }

        let now = Date.now
        let renewals = plannedNotifications(subscriptions: [subscription], now: now)
        // 金額を記録した直後にもここを通るため、リマインドも組み直します。
        // 記録済みの月は計画から外れ、下の掃除で取り消されます。
        let reminders = ReminderPlanner.plannedReminders(
            subscriptions: [subscription],
            now: now,
            limit: reminderBudget
        )
        let result = await add(notifications: renewals + reminders)
        guard !Task.isCancelled, result.failed == 0 else { return }

        // この費目の予約だけを対象にし、さらに名前空間ごとに掃除します。
        let ownIdentifiers = NotificationIdentifier.all(
            pending: pending.map(\.identifier),
            clientID: subscription.clientID
        )
        let obsoleteIdentifiers = NotificationIdentifier.obsolete(
            pending: ownIdentifiers,
            desired: Set(renewals.map(\.identifier)),
            in: .renewal
        ) + NotificationIdentifier.obsolete(
            pending: ownIdentifiers,
            desired: Set(reminders.map(\.identifier)),
            in: .reminder
        )
        center.removePendingNotificationRequests(withIdentifiers: obsoleteIdentifiers)
    }

    static func reconcile(
        subscriptions: [Subscription],
        loans: [Loan] = [],
        loanLead: LoanNotificationLead = LoanNotificationSettings.Defaults.lead,
        loanHour: Int = LoanNotificationSettings.Defaults.hour,
        now: Date = .now
    ) async -> SyncResult {
        guard !Task.isCancelled else {
            return SyncResult(scheduled: 0, failed: 0)
        }
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard !Task.isCancelled else {
            return SyncResult(scheduled: 0, failed: 0)
        }
        // リマインドを先に確保し、残りの枠を更新日通知へ回します。
        let reminders = ReminderPlanner.plannedReminders(
            subscriptions: subscriptions,
            now: now,
            limit: reminderBudget
        )
        let loanPayments = LoanNotificationPlanner.plannedPayments(
            loans: loans,
            now: now,
            limit: loanBudget,
            lead: loanLead,
            hour: loanHour
        )
        let renewals = plannedNotifications(
            subscriptions: subscriptions,
            now: now,
            limit: maximumPendingRequests - reminders.count - loanPayments.count
        )
        let result = await add(notifications: renewals + reminders + loanPayments)
        guard !Task.isCancelled, result.failed == 0 else { return result }

        let pendingIdentifiers = pending.map(\.identifier)
        // 名前空間ごとに掃除します。まとめて消すと、片方の再スケジュールが
        // もう片方の予約を巻き添えにします。
        let obsoleteIdentifiers = NotificationIdentifier.obsolete(
            pending: pendingIdentifiers,
            desired: Set(renewals.map(\.identifier)),
            in: .renewal
        ) + NotificationIdentifier.obsolete(
            pending: pendingIdentifiers,
            desired: Set(reminders.map(\.identifier)),
            in: .reminder
        ) + NotificationIdentifier.obsolete(
            pending: pendingIdentifiers,
            desired: Set(loanPayments.map(\.identifier)),
            in: .loan
        )
        center.removePendingNotificationRequests(withIdentifiers: obsoleteIdentifiers)
        return result
    }

    /// 費目を削除したときに、その費目の予約を取り消します。
    /// 更新日通知とリマインドの**両方**が対象です。片方だけ消すと、消えた費目の通知が届き続けます。
    static func cancel(clientID: String) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let identifiers = NotificationIdentifier.all(
            pending: pending.map(\.identifier),
            clientID: clientID
        )
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    static func plannedNotifications(
        subscriptions: [Subscription],
        now: Date,
        limit: Int = maximumPendingRequests,
        calendar: Calendar = .current
    ) -> [PlannedNotification] {
        guard limit > 0 else { return [] }

        var queues = subscriptions
            .filter { $0.notificationsEnabled && $0.state == .active }
            .map {
                notificationCandidates(for: $0, now: now, calendar: calendar)
                    .sorted { $0.date < $1.date }
            }
            .filter { !$0.isEmpty }
            .sorted {
                guard let lhs = $0.first, let rhs = $1.first else { return false }
                if lhs.date == rhs.date {
                    return lhs.clientID < rhs.clientID
                }
                return lhs.date < rhs.date
            }

        var result: [PlannedNotification] = []
        while result.count < limit {
            var addedInRound = false
            for index in queues.indices where result.count < limit {
                guard !queues[index].isEmpty else { continue }
                result.append(queues[index].removeFirst())
                addedInRound = true
            }
            if !addedInRound { break }
        }
        return result
    }

    private static func notificationCandidates(
        for subscription: Subscription,
        now: Date,
        calendar: Calendar
    ) -> [PlannedNotification] {
        let renewalDates = subscription.upcomingRenewalDates(
            onOrAfter: now,
            limit: renewalCyclesPerSubscription,
            calendar: calendar
        )

        return renewalDates.flatMap { renewalDate -> [PlannedNotification] in
            var targetComponents = calendar.dateComponents(
                [.year, .month, .day],
                from: renewalDate
            )
            targetComponents.hour = subscription.notificationHour
            targetComponents.minute = subscription.notificationMinute
            guard let targetDate = calendar.date(from: targetComponents) else { return [] }

            let cycleKey = targetDate.formatted(
                .iso8601.year().month().day().time(includingFractionalSeconds: false)
            )
            let offsets: [(String, Date)] =
                subscription.leadDays.compactMap { day in
                    calendar.date(byAdding: .day, value: -day, to: targetDate)
                        .map { ("day-\(day)", $0) }
                } +
                subscription.leadHours.compactMap { hour in
                    calendar.date(byAdding: .hour, value: -hour, to: targetDate)
                        .map { ("hour-\(hour)", $0) }
                }

            return offsets.compactMap { suffix, date in
                guard date > now else { return nil }
                return PlannedNotification(
                    clientID: subscription.clientID,
                    identifier: NotificationIdentifier.renewal(
                        clientID: subscription.clientID,
                        cycleKey: cycleKey,
                        suffix: suffix
                    ),
                    date: date,
                    title: "\(subscription.name)の更新予定",
                    body: "\(targetDate.formatted(date: .abbreviated, time: .shortened))に更新されます。"
                )
            }
        }
    }

    private static func add(notifications: [PlannedNotification]) async -> SyncResult {
        let center = UNUserNotificationCenter.current()
        var scheduled = 0
        var failed = 0

        for notification in notifications {
            guard !Task.isCancelled else { break }
            let content = UNMutableNotificationContent()
            content.title = notification.title
            content.body = notification.body
            content.sound = .default
            if let categoryIdentifier = notification.categoryIdentifier {
                content.categoryIdentifier = categoryIdentifier
            }
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: notification.date
                ),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: notification.identifier,
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
                scheduled += 1
            } catch {
                failed += 1
            }
        }
        return SyncResult(scheduled: scheduled, failed: failed)
    }
}
