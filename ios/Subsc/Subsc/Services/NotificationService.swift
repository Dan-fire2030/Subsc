import Foundation
import UserNotifications

@MainActor
enum NotificationService {
    private static let identifierPrefix = "subsc-"
    private static let maximumPendingRequests = 64
    private static let renewalCyclesPerSubscription = 12

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

        let desired = plannedNotifications(
            subscriptions: [subscription],
            now: .now
        )
        let result = await add(notifications: desired)
        guard !Task.isCancelled, result.failed == 0 else { return }

        let desiredIdentifiers = Set(desired.map(\.identifier))
        let prefix = "\(identifierPrefix)\(subscription.clientID)-"
        let obsoleteIdentifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) && !desiredIdentifiers.contains($0) }
        center.removePendingNotificationRequests(withIdentifiers: obsoleteIdentifiers)
    }

    static func reconcile(
        subscriptions: [Subscription],
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
        let desired = plannedNotifications(subscriptions: subscriptions, now: now)
        let result = await add(notifications: desired)
        guard !Task.isCancelled, result.failed == 0 else { return result }

        let desiredIdentifiers = Set(desired.map(\.identifier))
        let obsoleteIdentifiers = pending
            .map(\.identifier)
            .filter {
                $0.hasPrefix(identifierPrefix) && !desiredIdentifiers.contains($0)
            }
        center.removePendingNotificationRequests(withIdentifiers: obsoleteIdentifiers)
        return result
    }

    static func cancel(clientID: String) async {
        let center = UNUserNotificationCenter.current()
        let prefix = "\(identifierPrefix)\(clientID)-"
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
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
                    identifier: "\(identifierPrefix)\(subscription.clientID)-\(cycleKey)-\(suffix)",
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
